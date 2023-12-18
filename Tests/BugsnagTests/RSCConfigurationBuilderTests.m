#import <XCTest/XCTest.h>

#import <RSCrashReporter/RSCrashReporter.h>
#import "RSCConfigurationBuilder.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterTestConstants.h"
#import <TargetConditionals.h>

@interface RSCConfigurationBuilderTests : XCTestCase
@end

@implementation RSCConfigurationBuilderTests

// MARK: - rejecting invalid plists

- (void)testDecodeEmptyApiKey {
    RSCrashReporterConfiguration *configuration;
    XCTAssertNoThrow(configuration = RSCConfigurationWithOptions(@{@"apiKey": @""}));
    XCTAssertEqualObjects(configuration.apiKey, @"");
    XCTAssertThrows([configuration validate]);
}

- (void)testDecodeInvalidTypeApiKey {
    XCTAssertThrows(RSCConfigurationWithOptions(@{@"apiKey": @[@"one"]}));
}

- (void)testDecodeWithoutApiKey {
    RSCrashReporterConfiguration *configuration;
    XCTAssertNoThrow(configuration = RSCConfigurationWithOptions(@{@"autoDetectErrors": @NO}));
    XCTAssertNil(configuration.apiKey);
    XCTAssertFalse(configuration.autoDetectErrors);
    XCTAssertThrows([configuration validate]);
}

- (void)testDecodeUnknownKeys {
    RSCrashReporterConfiguration *config = RSCConfigurationWithOptions(@{
            @"giraffes": @3,
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);
}

- (void)testDecodeEmptyOptions {
    XCTAssertNoThrow(RSCConfigurationWithOptions(@{}));
}

// MARK: - config loading

- (void)testDecodeDefaultValues {
    RSCrashReporterConfiguration *config = RSCConfigurationWithOptions(@{@"apiKey": DUMMY_APIKEY_32CHAR_1});
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(DUMMY_APIKEY_32CHAR_1, config.apiKey);
    XCTAssertNotNil(config.appType);
    XCTAssertEqualObjects(config.appVersion, NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]);
    XCTAssertTrue(config.autoDetectErrors);
    XCTAssertTrue(config.autoTrackSessions);
    XCTAssertEqual(config.maxPersistedEvents, 32);
    XCTAssertEqual(config.maxPersistedSessions, 128);
    XCTAssertEqual(config.maxBreadcrumbs, 100);
    XCTAssertTrue(config.persistUser);
    XCTAssertEqualObjects(@[@"password"], [config.redactedKeys allObjects]);
    XCTAssertEqual(RSCEnabledBreadcrumbTypeAll, config.enabledBreadcrumbTypes);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);
#if !TARGET_OS_WATCH
    XCTAssertTrue(config.enabledErrorTypes.ooms);
    XCTAssertEqual(RSCThreadSendPolicyAlways, config.sendThreads);
#endif

#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
#endif

    XCTAssertNil(config.enabledReleaseStages);
    XCTAssertTrue(config.enabledErrorTypes.unhandledExceptions);
    XCTAssertTrue(config.enabledErrorTypes.cppExceptions);
    XCTAssertTrue(config.enabledErrorTypes.unhandledRejections);
#if !TARGET_OS_WATCH
    XCTAssertTrue(config.enabledErrorTypes.signals);
    XCTAssertTrue(config.enabledErrorTypes.machExceptions);
#endif
}

- (void)testDecodeFullConfig {
    RSCrashReporterConfiguration *config =
    RSCConfigurationWithOptions(@{
                    @"apiKey": DUMMY_APIKEY_32CHAR_1,
                    @"appType": @"cocoa-custom",
                    @"appVersion": @"5.2.33",
                    @"autoDetectErrors": @NO,
                    @"autoTrackSessions": @NO,
                    @"bundleVersion": @"7.22",
                    @"endpoints": @{
                            @"notify": @"https://reports.example.co",
                            @"sessions": @"https://sessions.example.co"
                    },
                    @"enabledReleaseStages": @[@"beta2", @"prod"],
                    @"maxPersistedEvents": @29,
                    @"maxPersistedSessions": @19,
                    @"maxBreadcrumbs": @27,
                    @"persistUser": @NO,
                    @"redactedKeys": @[@"foo"],
                    @"sendThreads": @"never",
                    @"releaseStage": @"beta1",
            });
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(DUMMY_APIKEY_32CHAR_1, config.apiKey);
    XCTAssertEqualObjects(@"cocoa-custom", config.appType);
    XCTAssertEqualObjects(@"5.2.33", config.appVersion);
    XCTAssertFalse(config.autoDetectErrors);
    XCTAssertFalse(config.autoTrackSessions);
    XCTAssertEqualObjects(@"7.22", config.bundleVersion);
    XCTAssertEqual(29, config.maxPersistedEvents);
    XCTAssertEqual(19, config.maxPersistedSessions);
    XCTAssertEqual(27, config.maxBreadcrumbs);
    XCTAssertFalse(config.persistUser);
    XCTAssertEqualObjects(config.redactedKeys, [NSSet setWithObject:@"foo"]);
    XCTAssertEqualObjects(@"beta1", config.releaseStage);
    XCTAssertEqualObjects(@"https://reports.example.co", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.example.co", config.endpoints.sessions);

    XCTAssertEqualObjects(config.enabledReleaseStages, ([NSSet setWithObjects:@"beta2", @"prod", nil]));

    XCTAssertTrue(config.enabledErrorTypes.unhandledExceptions);
    XCTAssertTrue(config.enabledErrorTypes.cppExceptions);
    XCTAssertTrue(config.enabledErrorTypes.unhandledRejections);

#if !TARGET_OS_WATCH
    XCTAssertEqual(RSCThreadSendPolicyNever, config.sendThreads);
    XCTAssertTrue(config.enabledErrorTypes.ooms);
    XCTAssertTrue(config.enabledErrorTypes.signals);
    XCTAssertTrue(config.enabledErrorTypes.machExceptions);
#endif
}

// MARK: - individual values

#define TEST_BOOL(key) ({ \
    XCTAssertEqual(RSCConfigurationWithOptions(@{@#key: @YES}).key, YES); \
    XCTAssertEqual(RSCConfigurationWithOptions(@{@#key: @NO}).key, NO); \
})

#define TEST_NUMBER(key, value1, value2) ({ \
    XCTAssertEqual(RSCConfigurationWithOptions(@{@#key: @value1}).key, value1); \
    XCTAssertEqual(RSCConfigurationWithOptions(@{@#key: @value2}).key, value2); \
})

#if !TARGET_OS_WATCH
- (void)testAppHangThresholdMillis {
    TEST_NUMBER(appHangThresholdMillis, 250, 2000);
}
#endif

- (void)testAttemptDeliveryOnCrash {
    TEST_BOOL(attemptDeliveryOnCrash);
}

- (void)testDiscardClasses {
    XCTAssertEqualObjects(RSCConfigurationWithOptions(@{@"discardClasses": @[@"one", @"two"]})
                          .discardClasses, ([NSSet setWithObjects:@"one", @"two", nil]));
}

- (void)testLaunchDurationMillis {
    TEST_NUMBER(launchDurationMillis, 250, 2000);
}

- (void)testMaxStringValueLength {
    TEST_NUMBER(maxStringValueLength, 250, 2000);
}

#if !TARGET_OS_WATCH
- (void)testReportBackgroundAppHangs {
    TEST_BOOL(reportBackgroundAppHangs);
}
#endif

- (void)testSendLaunchCrashesSynchronously {
    TEST_BOOL(sendLaunchCrashesSynchronously);
}

// MARK: - invalid config options

- (void)testInvalidConfigOptions {
    RSCrashReporterConfiguration *config =
    RSCConfigurationWithOptions(@{
                    @"apiKey": DUMMY_APIKEY_32CHAR_1,
                    @"appType": @[],
                    @"appVersion": @99,
                    @"autoDetectErrors": @67,
                    @"autoTrackSessions": @"NO",
                    @"bundleVersion": @{},
                    @"endpoints": [NSNull null],
                    @"enabledReleaseStages": @[@"beta2", @"prod"],
                    @"enabledErrorTypes": @[@"ooms", @"signals"],
                    @"maxPersistedEvents": @29,
                    @"maxPersistedSessions": @19,
                    @"maxBreadcrumbs": @27,
                    @"persistUser": @"pomelo",
                    @"redactedKeys": @[@77],
                    @"sendThreads": @"nev",
                    @"releaseStage": @YES,
            });
    XCTAssertNotNil(config); // no exception should be thrown when loading
}

- (void)testDecodeEnabledReleaseStagesInvalidTypes {
    RSCrashReporterConfiguration *config = RSCConfigurationWithOptions(@{
            @"enabledReleaseStages": @[@"beta", @"prod", @300],
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);
    XCTAssertNil(config.enabledReleaseStages);

    config = RSCConfigurationWithOptions(@{
            @"enabledReleaseStages": @{@"name": @"foo"},
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);
    XCTAssertNil(config.enabledReleaseStages);

    config = RSCConfigurationWithOptions(@{
            @"enabledReleaseStages": @"fooo",
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);
    XCTAssertNil(config.enabledReleaseStages);
}

- (void)testDecodeEndpointsInvalidTypes {
    RSCrashReporterConfiguration *config = RSCConfigurationWithOptions(@{
            @"endpoints": @"foo",
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);

    config = RSCConfigurationWithOptions(@{
            @"endpoints": @[@"http://example.com", @"http://foo.example.com"],
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);

    config = RSCConfigurationWithOptions(@{
            @"endpoints": @{},
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);
}

- (void)testDecodeEndpointsOnlyNotifySet {
    RSCrashReporterConfiguration *config = RSCConfigurationWithOptions(@{
            @"apiKey": DUMMY_APIKEY_32CHAR_1,
            @"endpoints": @{
                    @"notify": @"https://notify.example.com",
            },
    });
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.example.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);
}

- (void)testDecodeEndpointsOnlySessionsSet {
    RSCrashReporterConfiguration *config = RSCConfigurationWithOptions(@{
            @"apiKey": DUMMY_APIKEY_32CHAR_1,
            @"endpoints": @{@"sessions": @"https://sessions.example.com"},
    });
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.example.com", config.endpoints.sessions);
}

- (void)testDecodeReleaseStageInvalidType {
    RSCrashReporterConfiguration *config = RSCConfigurationWithOptions(@{
            @"releaseStage": @NO,
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    });
    XCTAssertNotNil(config);

#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
#endif
}

@end
