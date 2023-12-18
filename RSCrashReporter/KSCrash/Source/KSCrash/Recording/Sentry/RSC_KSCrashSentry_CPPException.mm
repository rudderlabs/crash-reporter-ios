//
//  RSC_KSCrashSentry_CPPException.c
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

#import <Foundation/Foundation.h>

#include "RSCDefines.h"
#include "RSC_KSCrashC.h"
#include "RSC_KSCrashSentry_CPPException.h"
#include "RSC_KSCrashSentry_Private.h"
#include "RSC_KSCrashStringConversion.h"
#include "RSC_KSMach.h"

//#define RSC_KSLogger_LocalLevel TRACE
#include "RSC_KSLogger.h"

#include <cxxabi.h>
#include <dlfcn.h>
#include <exception>
#include <execinfo.h>
#include <typeinfo>

#define STACKTRACE_BUFFER_LENGTH 30
#define DESCRIPTION_BUFFER_LENGTH 1000

// Compiler hints for "if" statements
#define unlikely_if(x) if (__builtin_expect(x, 0))

#ifdef __cplusplus
extern "C" {
#endif
// Internal NSException recorder
bool rsc_kscrashsentry_isNSExceptionHandlerInstalled(void);
void rsc_recordException(NSException *exception);
#ifdef __cplusplus
}
#endif

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** True if this handler has been installed. */
static volatile sig_atomic_t rsc_g_installed = 0;

/** True if the handler should capture the next stack trace. */
static bool rsc_g_captureNextStackTrace = false;

static std::terminate_handler rsc_g_originalTerminateHandler;

/** Buffer for the backtrace of the most recent exception. */
static uintptr_t rsc_g_stackTrace[STACKTRACE_BUFFER_LENGTH];

/** Number of backtrace entries in the most recent exception. */
static int rsc_g_stackTraceCount = 0;

/** Context to fill with crash information. */
static RSC_KSCrash_SentryContext *rsc_g_context;

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

typedef void (*cxa_throw_type)(void *, std::type_info *, void (*)(void *));

extern "C" {
void __cxa_throw(void *thrown_exception, std::type_info *tinfo,
                 void (*dest)(void *)) __attribute__((weak));

void __cxa_throw(void *thrown_exception, std::type_info *tinfo,
                 void (*dest)(void *)) {
    if (rsc_g_captureNextStackTrace) {
        rsc_g_stackTraceCount =
            backtrace((void **)rsc_g_stackTrace,
                      sizeof(rsc_g_stackTrace) / sizeof(*rsc_g_stackTrace));
    }

    static cxa_throw_type orig_cxa_throw = NULL;
    unlikely_if(orig_cxa_throw == NULL) {
        orig_cxa_throw = (cxa_throw_type)dlsym(RTLD_NEXT, "__cxa_throw");
    }
    orig_cxa_throw(thrown_exception, tinfo, dest);
    __builtin_unreachable();
}
}

static void CPPExceptionTerminate(void) {
    RSC_KSLOG_DEBUG("Trapped c++ exception");

    char descriptionBuff[DESCRIPTION_BUFFER_LENGTH];
    const char *name = NULL;
    const char *crashReason = NULL;

    RSC_KSLOG_DEBUG("Get exception type name.");
    std::type_info *tinfo = __cxxabiv1::__cxa_current_exception_type();
    if (tinfo != NULL) {
        name = tinfo->name();
    } else {
        name = "std::terminate";
        crashReason = "throw may have been called without an exception";
        if (!rsc_g_stackTraceCount) {
            RSC_KSLOG_DEBUG("No exception backtrace");
            rsc_g_stackTraceCount =
            backtrace((void **)rsc_g_stackTrace,
                      sizeof(rsc_g_stackTrace) / sizeof(*rsc_g_stackTrace));
        }
        goto after_rethrow; // Using goto to avoid indenting code below
    }

    RSC_KSLOG_DEBUG("Discovering what kind of exception was thrown.");
    rsc_g_captureNextStackTrace = false;
    try {
        throw;
    } catch (NSException *exception) {
        if (rsc_g_originalTerminateHandler != NULL) {
            RSC_KSLOG_DEBUG("Detected NSException. Passing to the current NSException handler.");
            rsc_g_originalTerminateHandler();
        } else {
            RSC_KSLOG_DEBUG("Detected NSException, but there was no original C++ terminate handler.");
        }
        return;
    } catch (std::exception &exc) {
        strlcpy(descriptionBuff, exc.what(), sizeof(descriptionBuff));
        crashReason = descriptionBuff;
    } catch (std::exception *exc) {
        strlcpy(descriptionBuff, exc->what(), sizeof(descriptionBuff));
        crashReason = descriptionBuff;
    }
#define CATCH_INT(TYPE)                                           \
    catch (TYPE value) {                                          \
        rsc_int64_to_string(value, descriptionBuff);              \
        crashReason = descriptionBuff;                            \
    }
#define CATCH_UINT(TYPE)                                          \
    catch (TYPE value) {                                          \
        rsc_uint64_to_string(value, descriptionBuff);             \
        crashReason = descriptionBuff;                            \
    }
#define CATCH_DOUBLE(TYPE)                                        \
    catch (TYPE value) {                                          \
        rsc_double_to_string((double)value, descriptionBuff, 16); \
        crashReason = descriptionBuff;                            \
    }
#define CATCH_STRING(TYPE)                                        \
    catch (TYPE value) {                                          \
        strncpy(descriptionBuff, value, sizeof(descriptionBuff)); \
        descriptionBuff[sizeof(descriptionBuff)-1] = 0;           \
        crashReason = descriptionBuff;                            \
    }

    CATCH_INT(char)
    CATCH_INT(short)
    CATCH_INT(int)
    CATCH_INT(long)
    CATCH_INT(long long)
    CATCH_UINT(unsigned char)
    CATCH_UINT(unsigned short)
    CATCH_UINT(unsigned int)
    CATCH_UINT(unsigned long)
    CATCH_UINT(unsigned long long)
    CATCH_DOUBLE(float)
    CATCH_DOUBLE(double)
    CATCH_DOUBLE(long double)
    CATCH_STRING(char *)
    catch (...) {
    }

after_rethrow:
    rsc_g_captureNextStackTrace = (rsc_g_installed != 0);

    if (rsc_kscrashsentry_beginHandlingCrash(rsc_ksmachthread_self())) {

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

        rsc_g_context->crashType = RSC_KSCrashTypeCPPException;
        rsc_g_context->registersAreValid = false;
        rsc_g_context->stackTrace =
            rsc_g_stackTrace + 1; // Don't record __cxa_throw stack entry
        rsc_g_context->stackTraceLength = rsc_g_stackTraceCount - 1;
        rsc_g_context->CPPException.name = name;
        rsc_g_context->crashReason = crashReason;

        RSC_KSLOG_DEBUG("Calling main crash handler.");
        rsc_g_context->onCrash(crashContextRSC());

        RSC_KSLOG_DEBUG(
            "Crash handling complete. Restoring original handlers.");
        rsc_kscrashsentry_uninstall((RSC_KSCrashType)RSC_KSCrashTypeAll);
#if RSC_HAVE_MACH_THREADS
        rsc_kscrashsentry_resumeThreads();
#endif
        rsc_kscrashsentry_endHandlingCrash();
    }
    if (rsc_g_originalTerminateHandler != NULL) {
        rsc_g_originalTerminateHandler();
    }
}

// ============================================================================
#pragma mark - Public API -
// ============================================================================

extern "C" bool rsc_kscrashsentry_installCPPExceptionHandler(
    RSC_KSCrash_SentryContext *context) {
    RSC_KSLOG_DEBUG("Installing C++ exception handler.");

    if (rsc_g_installed) {
        return true;
    }
    rsc_g_installed = 1;

    rsc_g_context = context;

    rsc_g_originalTerminateHandler = std::set_terminate(CPPExceptionTerminate);
    rsc_g_captureNextStackTrace = true;
    return true;
}

extern "C" void rsc_kscrashsentry_uninstallCPPExceptionHandler(void) {
    RSC_KSLOG_DEBUG("Uninstalling C++ exception handler.");
    if (!rsc_g_installed) {
        return;
    }

    rsc_g_captureNextStackTrace = false;
    std::set_terminate(rsc_g_originalTerminateHandler);
    rsc_g_installed = 0;
}
