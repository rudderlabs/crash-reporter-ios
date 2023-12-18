//
//  RSCCrashSentry.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import <Foundation/Foundation.h>

#import "RSC_KSCrashReportWriter.h"
#import "RSC_KSCrashType.h"

@class RSCrashReporterConfiguration;
@class RSCrashReporterErrorTypes;

NS_ASSUME_NONNULL_BEGIN

void RSCCrashSentryInstall(RSCrashReporterConfiguration *, RSC_KSReportWriteCallback);

RSC_KSCrashType RSC_KSCrashTypeFromRSCrashReporterErrorTypes(RSCrashReporterErrorTypes *);

NS_ASSUME_NONNULL_END
