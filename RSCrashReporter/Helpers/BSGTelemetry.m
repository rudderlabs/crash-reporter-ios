//
//  RSCTelemetry.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 05/07/2022.
//  Copyright © 2022 RSCrashReporter Inc. All rights reserved.
//

#import "RSCTelemetry.h"

#import "RSCDefines.h"
#import "RSC_KSMachHeaders.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterErrorTypes.h"

static NSNumber *_Nullable BooleanValue(BOOL actual, BOOL defaultValue) {
    return actual != defaultValue ? (actual ? @YES : @NO) : nil;
}

static NSNumber *_Nullable IntegerValue(NSUInteger actual, NSUInteger defaultValue) {
    return actual != defaultValue ? @(actual) : nil;
}

static BOOL IsStaticallyLinked(void) {
    return rsc_mach_headers_get_self_image() == rsc_mach_headers_get_main_image();
}

static NSDictionary * ConfigValue(RSCrashReporterConfiguration *configuration) {
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    
    RSCrashReporterConfiguration *defaults = [[RSCrashReporterConfiguration alloc] initWithApiKey:nil]; 
    
#if RSC_HAVE_APP_HANG_DETECTION
    config[@"appHangThresholdMillis"] = IntegerValue(configuration.appHangThresholdMillis, defaults.appHangThresholdMillis);
    config[@"reportBackgroundAppHangs"] = BooleanValue(configuration.reportBackgroundAppHangs, defaults.reportBackgroundAppHangs);
#endif
    
    config[@"attemptDeliveryOnCrash"] = BooleanValue(configuration.attemptDeliveryOnCrash, defaults.attemptDeliveryOnCrash);
    config[@"autoDetectErrors"] = BooleanValue(configuration.autoDetectErrors, defaults.autoDetectErrors);
    config[@"autoTrackSessions"] = BooleanValue(configuration.autoTrackSessions, defaults.autoTrackSessions);
    config[@"discardClassesCount"] = IntegerValue(configuration.discardClasses.count, 0);
    config[@"launchDurationMillis"] = IntegerValue(configuration.launchDurationMillis, defaults.launchDurationMillis);
    config[@"maxBreadcrumbs"] = IntegerValue(configuration.maxBreadcrumbs, defaults.maxBreadcrumbs);
    config[@"maxPersistedEvents"] = IntegerValue(configuration.maxPersistedEvents, defaults.maxPersistedEvents);
    config[@"maxPersistedSessions"] = IntegerValue(configuration.maxPersistedSessions, defaults.maxPersistedSessions);
    config[@"persistUser"] = BooleanValue(configuration.persistUser, defaults.persistUser);
    config[@"pluginCount"] = IntegerValue(configuration.plugins.count, 0);
    config[@"staticallyLinked"] = BooleanValue(IsStaticallyLinked(), NO);
    
    RSCEnabledBreadcrumbType enabledBreadcrumbTypes = configuration.enabledBreadcrumbTypes;
    if (enabledBreadcrumbTypes != defaults.enabledBreadcrumbTypes) {
        NSMutableArray *array = [NSMutableArray array];
        if (enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeError)         { [array addObject:@"error"]; }
        if (enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeLog)           { [array addObject:@"log"]; }
        if (enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeNavigation)    { [array addObject:@"navigation"]; }
        if (enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeProcess)       { [array addObject:@"process"]; }
        if (enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeRequest)       { [array addObject:@"request"]; }
        if (enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeState)         { [array addObject:@"state"]; }
        if (enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeUser)          { [array addObject:@"user"]; }
        config[@"enabledBreadcrumbTypes"] = [array componentsJoinedByString:@","];
    }
    
    RSCrashReporterErrorTypes *enabledErrorTypes = configuration.enabledErrorTypes;
    if (!enabledErrorTypes.cppExceptions ||
#if !TARGET_OS_WATCH
        !enabledErrorTypes.appHangs ||
        !enabledErrorTypes.ooms ||
        !enabledErrorTypes.thermalKills ||
        !enabledErrorTypes.signals ||
        !enabledErrorTypes.machExceptions ||
#endif
        !enabledErrorTypes.unhandledExceptions ||
        !enabledErrorTypes.unhandledRejections) {
        NSMutableArray *array = [NSMutableArray array];
#if !TARGET_OS_WATCH
        if (enabledErrorTypes.appHangs)             { [array addObject:@"appHangs"]; }
        if (enabledErrorTypes.machExceptions)       { [array addObject:@"machExceptions"]; }
        if (enabledErrorTypes.ooms)                 { [array addObject:@"ooms"]; }
        if (enabledErrorTypes.signals)              { [array addObject:@"signals"]; }
        if (enabledErrorTypes.thermalKills)         { [array addObject:@"thermalKills"]; }
#endif
        if (enabledErrorTypes.cppExceptions)        { [array addObject:@"cppExceptions"]; }
        if (enabledErrorTypes.unhandledExceptions)  { [array addObject:@"unhandledExceptions"]; }
        if (enabledErrorTypes.unhandledRejections)  { [array addObject:@"unhandledRejections"]; }
        [array sortedArrayUsingSelector:@selector(compare:)];
        config[@"enabledErrorTypes"] = [array componentsJoinedByString:@","];
    }
    
#if RSC_HAVE_MACH_THREADS
    if (configuration.sendThreads != defaults.sendThreads) {
        switch (configuration.sendThreads) {
            case RSCThreadSendPolicyAlways:
                config[@"sendThreads"] = @"always";
                break;
            case RSCThreadSendPolicyUnhandledOnly:
                config[@"sendThreads"] = @"unhandledOnly";
                break;
            case RSCThreadSendPolicyNever:
                config[@"sendThreads"] = @"never";
                break;
            default:
                break;
        }
    }
#endif
    
    return config;
}

NSDictionary * RSCTelemetryCreateUsage(RSCrashReporterConfiguration *configuration) {
    if (!(configuration.telemetry & RSCTelemetryUsage)) {
        return nil;
    }
    
    NSMutableDictionary *callbacks = [NSMutableDictionary dictionary];
    callbacks[@"onBreadcrumb"] = IntegerValue(configuration.onBreadcrumbBlocks.count, 0);
    callbacks[@"onCrashHandler"] = configuration.onCrashHandler ? @1 : nil;
    callbacks[@"onSendError"] = IntegerValue(configuration.onSendBlocks.count, 0);
    callbacks[@"onSession"] = IntegerValue(configuration.onSessionBlocks.count, 0);
    
    return @{
        @"callbacks": callbacks,
        @"config": ConfigValue(configuration)
    };
}
