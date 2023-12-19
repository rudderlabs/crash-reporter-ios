//
//  RSCTelemetryTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 05/07/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <RSCrashReporter/RSCrashReporter.h>

#import "RSCTelemetry.h"
#import "RSCrashReporterTestConstants.h"

@interface RSCTelemetryTests : XCTestCase

@end

@implementation RSCTelemetryTests

static void OnCrashHandler(const RSC_KSCrashReportWriter *writer) {}

- (RSCrashReporterConfiguration *)createConfiguration {
    return [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
}

- (void)testEmptyWhenDefault {
    RSCrashReporterConfiguration *configuration = [self createConfiguration];
    XCTAssertEqualObjects(RSCTelemetryCreateUsage(configuration), (@{@"callbacks": @{}, @"config": @{}}));
}

- (void)testCallbacks {
    RSCrashReporterConfiguration *configuration = [self createConfiguration];
    [configuration addOnBreadcrumbBlock:^BOOL(RSCrashReporterBreadcrumb * _Nonnull breadcrumb) { return NO; }];
    [configuration addOnSendErrorBlock:^BOOL(RSCrashReporterEvent * _Nonnull event) { return NO; }];
    [configuration addOnSessionBlock:^BOOL(RSCrashReporterSession * _Nonnull session) { return NO; }];
    configuration.onCrashHandler = OnCrashHandler;
    NSDictionary *expected = @{@"config": @{},
                               @"callbacks": @{
                                   @"onBreadcrumb": @1,
                                   @"onCrashHandler": @1,
                                   @"onSendError": @1,
                                   @"onSession": @1,
                               }};
    XCTAssertEqualObjects(RSCTelemetryCreateUsage(configuration), expected);
}

- (void)testConfigValues {
    RSCrashReporterConfiguration *configuration = [self createConfiguration];
#if !TARGET_OS_WATCH
    configuration.appHangThresholdMillis = 250;
    configuration.sendThreads = RSCThreadSendPolicyUnhandledOnly;
#endif
    configuration.autoDetectErrors = NO;
    configuration.autoTrackSessions = NO;
    configuration.discardClasses = [NSSet setWithObject:@"SomeErrorClass"];
    configuration.launchDurationMillis = 1000;
    configuration.maxBreadcrumbs = 16;
    configuration.maxPersistedEvents = 4;
    configuration.maxPersistedSessions = 8;
    configuration.persistUser = NO;
    [configuration addPlugin:(id)[NSNull null]];
    NSDictionary *expected = @{@"callbacks": @{},
                               @"config": @{
#if !TARGET_OS_WATCH
                                   @"appHangThresholdMillis": @250,
                                   @"sendThreads": @"unhandledOnly",
#endif
                                   @"autoDetectErrors": @NO,
                                   @"autoTrackSessions": @NO,
                                   @"discardClassesCount": @1,
                                   @"launchDurationMillis": @1000,
                                   @"maxBreadcrumbs": @16,
                                   @"maxPersistedEvents": @4,
                                   @"maxPersistedSessions": @8,
                                   @"persistUser": @NO,
                                   @"pluginCount": @1,
                               }};
    XCTAssertEqualObjects(RSCTelemetryCreateUsage(configuration), expected);
}

- (void)testEnabledBreadcrumbTypes {
    RSCrashReporterConfiguration *configuration = [self createConfiguration];
    configuration.enabledBreadcrumbTypes &= ~RSCEnabledBreadcrumbTypeNavigation;
    XCTAssertEqualObjects(RSCTelemetryCreateUsage(configuration),
                          (@{@"callbacks": @{}, @"config": @{
                              @"enabledBreadcrumbTypes": @"error,log,process,request,state,user"}}));
}

- (void)testEnabledErrorTypes {
    RSCrashReporterConfiguration *configuration = [self createConfiguration];
    configuration.enabledErrorTypes.cppExceptions = NO;
#if TARGET_OS_WATCH
    NSString *expected = @"unhandledExceptions,unhandledRejections";
#else
    NSString *expected = @"appHangs,machExceptions,ooms,signals,thermalKills,unhandledExceptions,unhandledRejections";
#endif
    XCTAssertEqualObjects(RSCTelemetryCreateUsage(configuration),
                          (@{@"callbacks": @{}, @"config": @{
                              @"enabledErrorTypes": expected}}));
}

- (void)testNilWhenDisabled {
    RSCrashReporterConfiguration *configuration = [self createConfiguration];
    configuration.telemetry &= ~RSCTelemetryUsage;
    XCTAssertNil(RSCTelemetryCreateUsage(configuration));
}

@end
