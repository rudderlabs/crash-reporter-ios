//
//  RSC_KSCrashSentry_Signal.c
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

#include "RSCDefines.h"

#if RSC_HAVE_SIGNAL

#include "RSC_KSCrashSentry_Private.h"
#include "RSC_KSCrashSentry_Signal.h"

#include "RSC_KSMach.h"
#include "RSC_KSSignalInfo.h"
#include "RSC_KSCrashC.h"
#include "RSC_KSCrashStringConversion.h"

//#define RSC_KSLogger_LocalLevel TRACE
#include "RSC_KSLogger.h"

#include <errno.h>
#include <stdlib.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Flag noting if we've installed our custom handlers or not.
 * It's not fully thread safe, but it's safer than locking and slightly better
 * than nothing.
 */
static volatile sig_atomic_t rsc_g_installed = 0;

/** Flag noting if we should handle signals.
 * When other signal handlers are registered after ours we can't remove our
 * signal handlers without removing the others.
 * It's not fully thread safe, but it's safer than locking and slightly better
 * than nothing.
 */
static volatile sig_atomic_t rsc_g_enabled = 0;

#if RSC_HAVE_SIGALTSTACK
/** Our custom signal stack. The signal handler will use this as its stack. */
static stack_t rsc_g_signalStack = {0};
#endif

/** Signal handlers that were installed before we installed ours. */
static struct sigaction *rsc_g_previousSignalHandlers = NULL;

/** Context to fill with crash information. */
static RSC_KSCrash_SentryContext *rsc_g_context;

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

static struct sigaction *get_previous_sigaction(int sigNum) {
    const int *fatalSignals = rsc_kssignal_fatalSignals();
    int fatalSignalsCount = rsc_kssignal_numFatalSignals();
    for (int i = 0; i < fatalSignalsCount; i++) {
        if(fatalSignals[i] == sigNum) {
            return &rsc_g_previousSignalHandlers[i];
        }
    }
    return NULL;
}

// Avoiding static functions due to linker issues.

/** Our custom signal handler.
 * Restore the default signal handlers, record the signal information, and
 * write a crash report.
 * Once we're done, re-raise the signal and let the default handlers deal with
 * it.
 *
 * @param sigNum The signal that was raised.
 *
 * @param signalInfo Information about the signal.
 *
 * @param userContext Other contextual information.
 */
void rsc_kssighndl_i_handleSignal(int sigNum, siginfo_t *signalInfo,
                                  void *userContext) {
    RSC_KSLOG_DEBUG("Trapped signal %d", sigNum);
    if (rsc_g_enabled &&
        rsc_kscrashsentry_beginHandlingCrash(rsc_ksmachthread_self())) {

        RSC_KSLOG_DEBUG("Suspending all threads.");
        rsc_kscrashsentry_suspendThreads();

        RSC_KSLOG_DEBUG("Filling out context.");
        rsc_g_context->crashType = RSC_KSCrashTypeSignal;
        rsc_g_context->registersAreValid = true;
        rsc_g_context->faultAddress = (uintptr_t)signalInfo->si_addr;
        rsc_g_context->signal.userContext = userContext;
        rsc_g_context->signal.signalInfo = signalInfo;

        RSC_KSLOG_DEBUG("Calling main crash handler.");
        rsc_g_context->onCrash(crashContext());

        RSC_KSLOG_DEBUG(
            "Crash handling complete. Restoring original handlers.");
        rsc_kscrashsentry_uninstall(RSC_KSCrashTypeAsyncSafe);
        rsc_kscrashsentry_resumeThreads();
        rsc_kscrashsentry_endHandlingCrash();
    }

    RSC_KSLOG_DEBUG(
        "Re-raising or chaining signal for regular handlers to catch.");
    struct sigaction *previous = get_previous_sigaction(sigNum);
    if(previous == NULL) {
        RSC_KSLOG_ERROR("BUG: Could not find handler for signal %d", sigNum);
        return;
    }
    if (previous->sa_flags & SA_SIGINFO) {
        previous->sa_sigaction(sigNum, signalInfo, userContext);
    } else if (previous->sa_handler == SIG_DFL) {
        // This is technically not allowed, but it works in OSX and iOS.
        signal(sigNum, SIG_DFL);
        raise(sigNum);
    } else if (previous->sa_handler != SIG_IGN) {
        previous->sa_handler(sigNum);
    }
}

// ============================================================================
#pragma mark - API -
// ============================================================================

bool rsc_kscrashsentry_installSignalHandler(
    RSC_KSCrash_SentryContext *context) {
    RSC_KSLOG_DEBUG("Installing signal handler.");

    if (!rsc_g_enabled) {
        rsc_g_enabled = 1;
        RSC_KSLOG_DEBUG("Signal handlers enabled.");
    }
    if (rsc_g_installed) {
        return true;
    }
    rsc_g_installed = 1;

    rsc_g_context = context;

#if RSC_HAVE_SIGALTSTACK
    if (rsc_g_signalStack.ss_size == 0) {
        RSC_KSLOG_DEBUG("Allocating signal stack area.");
        rsc_g_signalStack.ss_size = SIGSTKSZ;
        rsc_g_signalStack.ss_sp = malloc(rsc_g_signalStack.ss_size);
    }

    RSC_KSLOG_DEBUG("Setting signal stack area.");
    if (sigaltstack(&rsc_g_signalStack, NULL) != 0) {
        RSC_KSLOG_ERROR("signalstack: %s", strerror(errno));
        goto failed;
    }
#endif

    const int *fatalSignals = rsc_kssignal_fatalSignals();
    int fatalSignalsCount = rsc_kssignal_numFatalSignals();

    if (rsc_g_previousSignalHandlers == NULL) {
        RSC_KSLOG_DEBUG("Allocating memory to store previous signal handlers.");
        rsc_g_previousSignalHandlers =
            malloc(sizeof(*rsc_g_previousSignalHandlers) *
                   (unsigned)fatalSignalsCount);
    }

    struct sigaction action = {{0}};
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
#ifdef __LP64__
    action.sa_flags |= SA_64REGSET;
#endif
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = &rsc_kssighndl_i_handleSignal;

    for (int i = 0; i < fatalSignalsCount; i++) {
        RSC_KSLOG_DEBUG("Assigning handler for signal %d", fatalSignals[i]);
        if (sigaction(fatalSignals[i], &action,
                      &rsc_g_previousSignalHandlers[i]) != 0) {
#if RSC_KSLOG_PRINTS_AT_LEVEL(RSC_KSLogger_Level_Error)
            char sigNameBuff[30];
            const char *sigName = rsc_kssignal_signalName(fatalSignals[i]);
            if (sigName == NULL) {
                rsc_int64_to_string(fatalSignals[i], sigNameBuff);
                sigName = sigNameBuff;
            }
            RSC_KSLOG_ERROR("sigaction (%s): %s", sigName, strerror(errno));
#endif
            // Try to reverse the damage
            for (i--; i >= 0; i--) {
                sigaction(fatalSignals[i], &rsc_g_previousSignalHandlers[i],
                          NULL);
            }
            goto failed;
        }
        if (fatalSignals[i] == SIGPIPE &&
            rsc_g_previousSignalHandlers[i].sa_handler == SIG_IGN) {
            RSC_KSLOG_DEBUG("Removing handler for signal %d", fatalSignals[i]);
            sigaction(fatalSignals[i], &rsc_g_previousSignalHandlers[i], NULL);
        }
    }
    RSC_KSLOG_DEBUG("Signal handlers installed.");
    return true;

failed:
    RSC_KSLOG_DEBUG("Failed to install signal handlers.");
    rsc_g_enabled = 0;
    rsc_g_installed = 0;
    return false;
}

void rsc_kscrashsentry_uninstallSignalHandler(void) {
    RSC_KSLOG_DEBUG("Uninstalling signal handlers.");
    // We only disable signal handling but don't uninstall the signal handlers.
    //
    // The probblem is that we can safely uninstall signal handlers only when we
    // are the last one registered. If we are not we can't know how many
    // handlers were registered after us to re-register them. Also other
    // handlers could save our handler to chain the signal and our handler will
    // be called even when "uninstalled".
    //
    // Therefore keep the signal handlers installed and just disable the
    // handling. The installed signal handlers still chains the signal even when
    // not handling.
    if (!rsc_g_enabled) {
        return;
    }

    RSC_KSLOG_DEBUG("Signal handlers disabled.");
    rsc_g_enabled = 0;
}

#endif
