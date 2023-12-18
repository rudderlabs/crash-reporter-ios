//
//  RSC_KSCrashSentry.c
//
//  Created by Karl Stenerud on 2012-02-12.
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

#include "RSC_KSCrashSentry.h"
#include "RSC_KSCrashSentry_Private.h"

#include "RSC_KSCrashSentry_CPPException.h"
#include "RSC_KSCrashSentry_NSException.h"
#include "RSC_KSCrashSentry_MachException.h"
#include "RSC_KSCrashSentry_Signal.h"
#include "RSC_KSLogger.h"
#include "RSC_KSMach.h"
#include "RSCDefines.h"

#include <stdatomic.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

typedef struct {
    RSC_KSCrashType crashType;
    bool (*install)(RSC_KSCrash_SentryContext *context);
    void (*uninstall)(void);
} RSC_CrashSentry;

static RSC_CrashSentry rsc_g_sentries[] = {
#if RSC_HAVE_MACH_EXCEPTIONS
    {
        RSC_KSCrashTypeMachException, rsc_kscrashsentry_installMachHandler,
        rsc_kscrashsentry_uninstallMachHandler,
    },
#endif
#if RSC_HAVE_SIGNAL
    {
        RSC_KSCrashTypeSignal, rsc_kscrashsentry_installSignalHandler,
        rsc_kscrashsentry_uninstallSignalHandler,
    },
#endif
    {
        RSC_KSCrashTypeCPPException,
        rsc_kscrashsentry_installCPPExceptionHandler,
        rsc_kscrashsentry_uninstallCPPExceptionHandler,
    },
    {
        RSC_KSCrashTypeNSException, rsc_kscrashsentry_installNSExceptionHandler,
        rsc_kscrashsentry_uninstallNSExceptionHandler,
    },
};
static size_t rsc_g_sentriesCount =
    sizeof(rsc_g_sentries) / sizeof(*rsc_g_sentries);

/** Context to fill with crash information. */
static RSC_KSCrash_SentryContext *rsc_g_context = NULL;

#if RSC_HAVE_MACH_THREADS
/** Keeps track of whether threads have already been suspended or not.
 * This won't handle multiple suspends in a row.
 */
static bool rsc_g_threads_are_running = true;
#endif

// ============================================================================
#pragma mark - API -
// ============================================================================

RSC_KSCrashType
rsc_kscrashsentry_installWithContext(RSC_KSCrash_SentryContext *context,
                                     RSC_KSCrashType crashTypes,
                                     void (*onCrash)(void *)) {
    if (rsc_ksmachisBeingTraced()) {
        RSC_KSLOG_WARN("App is running in a debugger. "
                       "Only handled events will be sent to RSCrashReporter.");
        crashTypes = 0;
    } else {
        RSC_KSLOG_DEBUG(
            "Installing handlers with context %p, crash types 0x%x.", context,
            crashTypes);
    }

    rsc_g_context = context;
    rsc_kscrashsentry_clearContext(rsc_g_context);
    rsc_g_context->onCrash = onCrash;

    RSC_KSCrashType installed = 0;
    for (size_t i = 0; i < rsc_g_sentriesCount; i++) {
        RSC_CrashSentry *sentry = &rsc_g_sentries[i];
        if (sentry->crashType & crashTypes) {
            if (sentry->install == NULL || sentry->install(context)) {
                installed |= sentry->crashType;
            }
        }
    }

    RSC_KSLOG_DEBUG("Installation complete. Installed types 0x%x.", installed);
    return installed;
}

void rsc_kscrashsentry_uninstall(RSC_KSCrashType crashTypes) {
    RSC_KSLOG_DEBUG("Uninstalling handlers with crash types 0x%x.", crashTypes);
    for (size_t i = 0; i < rsc_g_sentriesCount; i++) {
        RSC_CrashSentry *sentry = &rsc_g_sentries[i];
        if (sentry->crashType & crashTypes) {
            if (sentry->install != NULL) {
                sentry->uninstall();
            }
        }
    }
    RSC_KSLOG_DEBUG("Uninstall complete.");
}

// ============================================================================
#pragma mark - Private API -
// ============================================================================

#if RSC_HAVE_MACH_THREADS
void rsc_kscrashsentry_suspendThreads(void) {
    RSC_KSLOG_DEBUG("Suspending threads.");
    if (!rsc_g_threads_are_running) {
        RSC_KSLOG_DEBUG("Threads already suspended.");
        return;
    }


    if (rsc_g_context != NULL) {
        rsc_g_context->allThreads = rsc_ksmachgetAllThreads(&rsc_g_context->allThreadsCount);
        rsc_ksmachgetThreadStates(rsc_g_context->allThreads, rsc_g_context->allThreadRunStates, rsc_g_context->allThreadsCount);
        rsc_g_context->threadsToResumeCount = rsc_ksmachremoveThreadsFromList(rsc_g_context->allThreads,
                                                                              rsc_g_context->allThreadsCount,
                                                                              rsc_g_context->reservedThreads,
                                                                              RSC_KSCrashReservedThreadTypeCount,
                                                                              rsc_g_context->threadsToResume,
                                                                              MAX_CAPTURED_THREADS);
        RSC_KSLOG_DEBUG("Suspending %d of %d threads.", rsc_g_context->threadsToResumeCount, rsc_g_context->allThreadsCount);
        rsc_ksmachsuspendThreads(rsc_g_context->threadsToResume, rsc_g_context->threadsToResumeCount);
    } else {
        RSC_KSLOG_DEBUG("Suspending all threads.");
        unsigned threadsCount = 0;
        thread_t *threads = rsc_ksmachgetAllThreads(&threadsCount);
        rsc_ksmachsuspendThreads(threads, threadsCount);
        rsc_ksmachfreeThreads(threads, threadsCount);
    }
    rsc_g_threads_are_running = false;
    RSC_KSLOG_DEBUG("Suspend complete.");
}

void rsc_kscrashsentry_resumeThreads(void) {
    RSC_KSLOG_DEBUG("Resuming threads.");
    if (rsc_g_threads_are_running) {
        RSC_KSLOG_DEBUG("Threads already resumed.");
        return;
    }

    if (rsc_g_context != NULL) {
        RSC_KSLOG_DEBUG("Resuming %d of %d threads.", rsc_g_context->threadsToResumeCount, rsc_g_context->allThreadsCount);
        rsc_ksmachresumeThreads(rsc_g_context->threadsToResume, rsc_g_context->threadsToResumeCount);
        rsc_g_context->threadsToResumeCount = 0;
        if (rsc_g_context->allThreads != NULL) {
            rsc_ksmachfreeThreads(rsc_g_context->allThreads, rsc_g_context->allThreadsCount);
            rsc_g_context->allThreads = NULL;
            rsc_g_context->allThreadsCount = 0;
        }
    } else {
        RSC_KSLOG_DEBUG("Resuming all threads.");
        unsigned threadsCount = 0;
        thread_t *threads = rsc_ksmachgetAllThreads(&threadsCount);
        rsc_ksmachresumeThreads(threads, threadsCount);
        rsc_ksmachfreeThreads(threads, threadsCount);
    }
    rsc_g_threads_are_running = true;
    RSC_KSLOG_DEBUG("Resume complete.");
}
#endif

void rsc_kscrashsentry_clearContext(RSC_KSCrash_SentryContext *context) {
    void (*onCrash)(void *) = context->onCrash;
    void (*attemptDelivery)(void) = context->attemptDelivery;
    bool threadTracingEnabled = context->threadTracingEnabled;
    thread_t reservedThreads[RSC_KSCrashReservedThreadTypeCount];
    memcpy(reservedThreads, context->reservedThreads, sizeof(reservedThreads));

    memset(context, 0, sizeof(*context));

    context->onCrash = onCrash;
    context->attemptDelivery = attemptDelivery;
    context->threadTracingEnabled = threadTracingEnabled;
    memcpy(context->reservedThreads, reservedThreads, sizeof(reservedThreads));
}

// Set to true once _endHandlingCrash() has been called and it is safe to resume
// any secondary crashed threads.
static atomic_bool rsc_g_didHandleCrash;

bool rsc_kscrashsentry_beginHandlingCrash(const thread_t offender) {
    static _Atomic(thread_t) firstOffender;
    static thread_t firstHandlingThread;

    thread_t expected = 0;
    if (atomic_compare_exchange_strong(&firstOffender, &expected, offender)) {
        firstHandlingThread = rsc_ksmachthread_self();
        RSC_KSLOG_DEBUG("Handling app crash in thread 0x%x", offender);
        rsc_kscrashsentry_clearContext(rsc_g_context);
        rsc_g_context->handlingCrash = true;
        rsc_g_context->offendingThread = offender;
        return true;
    }

    if (offender == firstHandlingThread) {
        RSC_KSLOG_INFO("Detected crash in the crash reporter. "
                       "Restoring original handlers.");
        rsc_kscrashsentry_uninstall(RSC_KSCrashTypeAsyncSafe);

        // Reset the context to write a recrash report.
        rsc_kscrashsentry_clearContext(rsc_g_context);
        rsc_g_context->crashedDuringCrashHandling = true;
        rsc_g_context->handlingCrash = true;
        rsc_g_context->offendingThread = offender;
        return true;
    }

    RSC_KSLOG_DEBUG("Ignoring secondary app crash in thread 0x%x", offender);
    // Block this thread to prevent the crash handling thread from being
    // interrupted while writing the crash report. If we allowed the default
    // handler to be triggered for this thread, the process would be killed
    // before the crash report can be written. The process will be killed by the
    // default handler once the handling thread has finished and threads resume.
    while (!atomic_load(&rsc_g_didHandleCrash)) {
        usleep(USEC_PER_SEC / 10);
    }
    return false;
}

void rsc_kscrashsentry_endHandlingCrash(void) {
    RSC_KSLOG_DEBUG("Noting completion of crash handling");
    atomic_store(&rsc_g_didHandleCrash, true);
}
