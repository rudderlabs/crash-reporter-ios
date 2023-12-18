//
//  RSCCrashSentry.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import "RSCCrashSentry.h"

#import "RSCEventUploader.h"
#import "RSCFileLocations.h"
#import "RSCUtils.h"
#import "RSC_KSCrash.h"
#import "RSC_KSCrashC.h"
#import "RSC_KSMach.h"
#import "RSCrashReporterClient+Private.h"
#import "RSCrashReporterInternals.h"
#import "RSCrashReporterLogger.h"

NSTimeInterval RSCCrashSentryDeliveryTimeout = 3;

static void RSCCrashSentryAttemptyDelivery(void);

void RSCCrashSentryInstall(RSCrashReporterConfiguration *config, RSC_KSReportWriteCallback onCrash) {
    RSC_KSCrash *ksCrash = [RSC_KSCrash sharedInstance];

    rsc_kscrash_setCrashNotifyCallback(onCrash);

#if RSC_HAVE_MACH_THREADS
    // overridden elsewhere for handled errors, so we can assume that this only
    // applies to unhandled errors
    rsc_kscrash_setThreadTracingEnabled(config.sendThreads != RSCThreadSendPolicyNever);
#endif

    RSC_KSCrashType crashTypes = 0;
    if (config.autoDetectErrors) {
        if (rsc_ksmachisBeingTraced()) {
            rsc_log_info(@"Unhandled errors will not be reported because a debugger is attached");
        } else {
            crashTypes = RSC_KSCrashTypeFromRSCrashReporterErrorTypes(config.enabledErrorTypes);
        }
        if (config.attemptDeliveryOnCrash) {
            rsc_log_debug(@"Enabling on-crash delivery");
            crashContextRSC()->crash.attemptDelivery = RSCCrashSentryAttemptyDelivery;
        }
    }

    NSString *crashReportsDirectory = RSCFileLocations.current.kscrashReports;

    // NSFileProtectionComplete prevents new crash reports being written when
    // the device is locked, so must be disabled.
    RSCDisableNSFileProtectionComplete(crashReportsDirectory);

    // In addition to installing crash handlers, -[RSC_KSCrash install:] initializes various
    // subsystems that RSCrashReporter relies on, so needs to be called even if autoDetectErrors is disabled.
    if ((![ksCrash install:crashTypes directory:crashReportsDirectory] && crashTypes)) {
        rsc_log_err(@"Failed to install crash handlers; no exceptions or crashes will be reported");
    }
}

/**
 * Map the RSCErrorType bitfield of reportable events to the equivalent KSCrash one.
 * OOMs are dealt with exclusively in the RSCrashReporter layer so omitted from consideration here.
 * User reported events should always be included and so also not dealt with here.
 *
 * @param errorTypes The enabled error types
 * @returns A RSC_KSCrashType equivalent (with the above caveats) to the input
 */
RSC_KSCrashType RSC_KSCrashTypeFromRSCrashReporterErrorTypes(RSCrashReporterErrorTypes *errorTypes) {
    return ((errorTypes.unhandledExceptions ?   RSC_KSCrashTypeNSException : 0)     |
            (errorTypes.cppExceptions ?         RSC_KSCrashTypeCPPException : 0)    |
#if !TARGET_OS_WATCH
            (errorTypes.signals ?               RSC_KSCrashTypeSignal : 0)          |
            (errorTypes.machExceptions ?        RSC_KSCrashTypeMachException : 0)   |
#endif
            0);
}

static void RSCCrashSentryAttemptyDelivery(void) {
    NSString *file = @(crashContextRSC()->config.crashReportFilePath);
    rsc_log_info(@"Attempting crash-time delivery of %@", file);
    int64_t timeout = (int64_t)(RSCCrashSentryDeliveryTimeout * NSEC_PER_SEC);
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, timeout);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [RSCrashReporter.client.eventUploader uploadKSCrashReportWithFile:file completionHandler:^{
        rsc_log_debug(@"Sent crash.");
        dispatch_semaphore_signal(semaphore);
    }];
    if (dispatch_semaphore_wait(semaphore, deadline)) {
        rsc_log_debug(@"Timed out waiting for crash to be sent.");
    }
}
