//
//  RSC_KSCrashSentry_NSException.m
//
//  Created by Karl Stenerud on 2012-01-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RSC_KSCrashSentry_NSException.h"

#import "RSCDefines.h"
#import "RSCJSONSerialization.h"
#import "RSCUtils.h"
#import "RSC_KSCrashC.h"
#import "RSC_KSCrashSentry_Private.h"
#import "RSC_KSMach.h"
#import "RSCrashReporterCollections.h"

//#define RSC_KSLogger_LocalLevel TRACE
#import "RSC_KSLogger.h"

#import <objc/runtime.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Flag noting if we've installed our custom handlers or not.
 * It's not fully thread safe, but it's safer than locking and slightly better
 * than nothing.
 */
static volatile sig_atomic_t rsc_g_installed = 0;

/** The exception handler that was in place before we installed ours. */
static NSUncaughtExceptionHandler *rsc_g_previousUncaughtExceptionHandler;

/** Context to fill with crash information. */
static RSC_KSCrash_SentryContext *rsc_g_context;

static NSException *rsc_lastHandledException = NULL;

static char * CopyUTF8String(NSString *string) {
    const char *UTF8String = [string UTF8String];
    return UTF8String ? strdup(UTF8String) : NULL;
}

static char * CopyJSON(NSDictionary *userInfo) {
    NSDictionary *json = RSCJSONDictionary(userInfo);
    NSData *data = RSCJSONDataFromDictionary(json, NULL);
    return RSCCStringWithData(data);
}

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================


// Avoiding static methods due to linker issue.
/**
 Capture exception details and write a new report. If the exception was
 recorded before, no new report will be generated.

 @param exception The exception to process
 */
void rsc_recordException(NSException *exception);

/** Our custom excepetion handler.
 * Fetch the stack trace from the exception and write a report.
 *
 * @param exception The exception that was raised.
 */
void rsc_ksnsexc_i_handleException(NSException *exception) {
    RSC_KSLOG_DEBUG("Trapped exception %s", exception.description.UTF8String);
    if (rsc_g_installed &&
        rsc_kscrashsentry_beginHandlingCrash(rsc_ksmachthread_self())) {

        rsc_recordException(exception);

        RSC_KSLOG_DEBUG(
            "Crash handling complete. Restoring original handlers.");
        rsc_kscrashsentry_uninstall(RSC_KSCrashTypeAll);

        // Must run before endHandlingCrash unblocks secondary crashed threads.
        RSC_KSCrash_Context *context = crashContextRSC();
        if (context->crash.attemptDelivery) {
            RSC_KSLOG_DEBUG("Attempting delivery.");
            context->crash.attemptDelivery();
        }

        rsc_kscrashsentry_endHandlingCrash();
    }

    if (rsc_g_previousUncaughtExceptionHandler != NULL) {
        RSC_KSLOG_DEBUG("Calling original exception handler.");
        rsc_g_previousUncaughtExceptionHandler(exception);
    }
}

void rsc_recordException(NSException *exception) {
    if (rsc_g_installed) {
        BOOL previouslyHandled = exception == rsc_lastHandledException;
        if (previouslyHandled) {
            RSC_KSLOG_DEBUG("Handled exception previously, "
                            "exiting exception recorder.");
            return;
        }
        rsc_lastHandledException = exception;
        RSC_KSLOG_DEBUG("Writing exception info into a new report");

        RSC_KSLOG_DEBUG("Filling out context.");
        NSArray *addresses = [exception callStackReturnAddresses];
        NSUInteger numFrames = [addresses count];
        uintptr_t *callstack = malloc(numFrames * sizeof(*callstack));
        if (callstack) {
            for (NSUInteger i = 0; i < numFrames; i++) {
                callstack[i] = [addresses[i] unsignedLongValue];
            }
        }

        rsc_g_context->crashType = RSC_KSCrashTypeNSException;
        rsc_g_context->offendingThread = rsc_ksmachthread_self();
        rsc_g_context->registersAreValid = false;
        rsc_g_context->NSException.name = CopyUTF8String([exception name]);
        rsc_g_context->NSException.userInfo = CopyJSON([exception userInfo]);
        rsc_g_context->crashReason = CopyUTF8String([exception reason]);
        rsc_g_context->stackTrace = callstack;
        rsc_g_context->stackTraceLength = callstack ? (int)numFrames : 0;

#if RSC_HAVE_MACH_THREADS
        RSC_KSLOG_DEBUG("Suspending all threads.");
        rsc_kscrashsentry_suspendThreads();
#else
        // We still need the threads list for other purposes:
        // - Stack traces
        // - Thread names
        // - Thread states
        rsc_g_context->allThreads = rsc_ksmachgetAllThreads(&rsc_g_context->allThreadsCount);
#endif

        RSC_KSLOG_DEBUG("Calling main crash handler.");
        rsc_g_context->onCrash(crashContextRSC());

#if RSC_HAVE_MACH_THREADS
        rsc_kscrashsentry_resumeThreads();
#endif
    }
}

// ============================================================================
#pragma mark - iOS apps on macOS -
// ============================================================================

// iOS apps behave a little differently when running on macOS via Catalyst or
// on Apple Silicon. Uncaught NSExceptions raised while handling UI events get
// caught by AppKit and are not propagated to NSUncaughtExceptionHandler or
// std::terminate_handler (reported to Apple: FB8901200) therefore we need
// another way to detect them...

#if TARGET_OS_IOS

static Method NSApplication_reportException;

/// Pointer to the real implementation of -[NSApplication reportException:]
static void (* NSApplication_reportException_imp)(id, SEL, NSException *);

/// Overrides -[NSApplication reportException:]
static void rsc_reportException(id self, SEL _cmd, NSException *exception) {
    RSC_KSLOG_DEBUG("reportException: %s", exception.description.UTF8String);

    if (rsc_kscrashsentry_beginHandlingCrash(rsc_ksmachthread_self())) {
        rsc_recordException(exception);
        rsc_kscrashsentry_endHandlingCrash();
    }

#if defined(TARGET_OS_MACCATALYST) && TARGET_OS_MACCATALYST
    // Mac Catalyst apps continue to run after an uncaught exception is thrown
    // while handling a UI event. Our crash sentries should remain installed to
    // catch any subsequent unhandled exceptions or crashes.
#else
    // iOS apps running on Apple Silicon Macs terminate with an EXC_BREAKPOINT
    // mach exception. We don't want to catch that because its stack trace will
    // not point to where the exception was raised (its top frame will be
    // -[NSApplication _crashOnException:]) so we should uninstall our crash
    // sentries.
    rsc_kscrashsentry_uninstall(RSC_KSCrashTypeAll);
#endif

    NSApplication_reportException_imp(self, _cmd, exception);
}

#endif

// ============================================================================
#pragma mark - API -
// ============================================================================

bool rsc_kscrashsentry_installNSExceptionHandler(
    RSC_KSCrash_SentryContext *const context) {
    RSC_KSLOG_DEBUG("Installing NSException handler.");
    if (rsc_g_installed) {
        return true;
    }
    rsc_g_installed = 1;

    rsc_g_context = context;

    RSC_KSLOG_DEBUG("Backing up original handler.");
    rsc_g_previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();

    RSC_KSLOG_DEBUG("Setting new handler.");
    NSSetUncaughtExceptionHandler(&rsc_ksnsexc_i_handleException);

#if TARGET_OS_IOS
    NSApplication_reportException =
    class_getInstanceMethod(NSClassFromString(@"NSApplication"),
                            NSSelectorFromString(@"reportException:"));
    if (NSApplication_reportException) {
        RSC_KSLOG_DEBUG("Overriding -[NSApplication reportException:]");
        NSApplication_reportException_imp = (void *)
        method_setImplementation(NSApplication_reportException,
                                 (IMP)rsc_reportException);
    }
#endif

    return true;
}

void rsc_kscrashsentry_uninstallNSExceptionHandler(void) {
    RSC_KSLOG_DEBUG("Uninstalling NSException handler.");
    if (!rsc_g_installed) {
        return;
    }

    RSC_KSLOG_DEBUG("Restoring original handler.");
    NSSetUncaughtExceptionHandler(rsc_g_previousUncaughtExceptionHandler);

#if TARGET_OS_IOS
    if (NSApplication_reportException && NSApplication_reportException_imp) {
        RSC_KSLOG_DEBUG("Restoring original -[NSApplication reportException:]");
        method_setImplementation(NSApplication_reportException,
                                 (IMP)NSApplication_reportException_imp);
    }
#endif

    rsc_g_installed = 0;
}

bool rsc_kscrashsentry_isNSExceptionHandlerInstalled(void) {
    return rsc_g_installed;
}
