//
//  RSC_KSCrashC.c
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

#include "RSC_KSCrashC.h"

#include "RSC_KSCrashReport.h"
#include "RSC_KSMach.h"
#include "RSC_KSMachHeaders.h"
#include "RSC_KSString.h"
#include "RSC_KSSystemInfoC.h"
#include "RSCDefines.h"

//#define RSC_KSLogger_LocalLevel TRACE
#include "RSC_KSLogger.h"

#include <mach/mach_time.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** True if RSC_KSCrash has been initialised. */
static volatile sig_atomic_t rsc_g_initialised = 0;

/** True if RSC_KSCrash has been installed. */
static volatile sig_atomic_t rsc_g_installed = 0;

/** Single, global crash context. */
static RSC_KSCrash_Context rsc_g_crashReportContext;

/** Path to store the state file. */
static char *rsc_g_stateFilePath;

// ============================================================================
#pragma mark - Utility -
// ============================================================================

RSC_KSCrash_Context *crashContextRSC(void) {
    return &rsc_g_crashReportContext;
}

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

// Avoiding static methods due to linker issue.

/** Called when a crash occurs.
 *
 * This function gets passed as a callback to a crash handler.
 */
void rsc_kscrash_i_onCrash(RSC_KSCrash_Context *context) {
    RSC_KSLOG_DEBUG("Updating application state to note crash.");

    rsc_kscrashstate_notifyAppCrash();

    if (context->crash.crashedDuringCrashHandling) {
        rsc_kscrashreport_writeMinimalReport(context,
                                             context->config.recrashReportFilePath);
    } else {
        rsc_kscrashreport_writeStandardReport(context, context->config.crashReportFilePath);
    }
}

// ============================================================================
#pragma mark - API -
// ============================================================================

void rsc_kscrash_init(void) {
    if (!rsc_g_initialised) {
        rsc_g_initialised = true;
        rsc_g_crashReportContext.config.handlingCrashTypes = RSC_KSCrashTypeProductionSafe;
    }
}

RSC_KSCrashType rsc_kscrash_install(const char *const crashReportFilePath,
                                    const char *const recrashReportFilePath,
                                    const char *stateFilePath,
                                    const char *crashID) {
    RSC_KSLOG_DEBUG("Installing crash reporter.");

    RSC_KSCrash_Context *context = crashContextRSC();
    
    if (rsc_g_installed) {
        RSC_KSLOG_DEBUG("Crash reporter already installed.");
        return context->config.handlingCrashTypes;
    }
    rsc_g_installed = 1;
    
    rsc_mach_headers_initialize();

    rsc_kscrash_reinstall(crashReportFilePath, recrashReportFilePath,
                          stateFilePath, crashID);

    RSC_KSCrashType crashTypes =
        rsc_kscrash_setHandlingCrashTypes(context->config.handlingCrashTypes);

    context->config.systemInfoJSON = rsc_kssysteminfo_toJSON();
    context->config.processName = rsc_kssysteminfo_copyProcessName();

    RSC_KSLOG_DEBUG("Installation complete.");
    return crashTypes;
}

void rsc_kscrash_reinstall(const char *const crashReportFilePath,
                           const char *const recrashReportFilePath,
                           const char *const stateFilePath,
                           const char *const crashID) {
    RSC_KSLOG_TRACE("reportFilePath = %s", crashReportFilePath);
    RSC_KSLOG_TRACE("secondaryReportFilePath = %s", recrashReportFilePath);
    RSC_KSLOG_TRACE("stateFilePath = %s", stateFilePath);
    RSC_KSLOG_TRACE("crashID = %s", crashID);

    rsc_ksstring_replace(&rsc_g_stateFilePath, stateFilePath);

    RSC_KSCrash_Context *context = crashContextRSC();
    rsc_ksstring_replace(&context->config.crashReportFilePath,
                         crashReportFilePath);
    rsc_ksstring_replace(&context->config.recrashReportFilePath,
                         recrashReportFilePath);
    rsc_ksstring_replace(&context->config.crashID, crashID);

    if (!rsc_kscrashstate_init(rsc_g_stateFilePath, &context->state)) {
        RSC_KSLOG_ERROR("Failed to initialize persistent crash state");
    }
}

RSC_KSCrashType rsc_kscrash_setHandlingCrashTypes(RSC_KSCrashType crashTypes) {
    RSC_KSCrash_Context *context = crashContextRSC();
    context->config.handlingCrashTypes = crashTypes;

    if (rsc_g_installed) {
        rsc_kscrashsentry_uninstall(~crashTypes);
        if (crashTypes) {
            crashTypes = rsc_kscrashsentry_installWithContext(
                &context->crash, crashTypes, (void(*)(void *))rsc_kscrash_i_onCrash);
        }
    }

    return crashTypes;
}

void rsc_kscrash_setCrashNotifyCallback(
    const RSC_KSReportWriteCallback onCrashNotify) {
    RSC_KSLOG_TRACE("Set onCrashNotify to %p", onCrashNotify);
    crashContextRSC()->config.onCrashNotify = onCrashNotify;
}

void rsc_kscrash_setThreadTracingEnabled(bool threadTracingEnabled) {
#if RSC_HAVE_MACH_THREADS
    crashContextRSC()->crash.threadTracingEnabled = threadTracingEnabled;
#else
    (void)threadTracingEnabled;
#endif
}
