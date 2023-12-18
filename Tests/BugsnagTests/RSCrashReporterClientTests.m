//
//  RSCrashReporterClientTests.m
//  Tests
//
//  Created by Robin Macharg on 18/03/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import "RSCInternalErrorReporter.h"
#import "RSCKeys.h"
#import "RSCRunContext.h"
#import "RSCrashReporter+Private.h"
#import "RSCrashReporterBreadcrumb+Private.h"
#import "RSCrashReporterBreadcrumbs.h"
#import "RSCrashReporterClient+Private.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterSystemState.h"
#import "RSCrashReporterTestConstants.h"
#import "RSCrashReporterUser.h"

#import <objc/runtime.h>
#import <XCTest/XCTest.h>

/**
 * Tests for RSCrashReporterClient.
 *
 * RSCrashReporterClient is an expensive object and not suitable for unit testing because it depends on and alters global
 * state like the file system and default notification center. Furthermore, instances never get deallocated - so
 * clients instantiated by previous test cases can alter the results of a client instantiated in a later test
 * case due to the shared global state.
 *
 * For these reasons, test cases should only be added here as a matter of last resort.
 */
@interface RSCrashReporterClientTests : XCTestCase
@end

NSString *RSCFormatSeverity(RSCSeverity severity);

@implementation RSCrashReporterClientTests

/**
 * A boilerplate helper method to setup RSCrashReporter
 */
-(RSCrashReporterClient *)setUpRSCrashReporterWillCallNotify:(bool)willNotify {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    if (willNotify) {
        [configuration addOnSendErrorBlock:^BOOL(RSCrashReporterEvent *_Nonnull event) {
            return false;
        }];
    }
    return [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
}

/**
 * Handled events leave a breadcrumb when notify() is called.  Test that values are inserted
 * correctly.
 */
- (void)testAutomaticNotifyBreadcrumbData {

    RSCrashReporterClient *client = [self setUpRSCrashReporterWillCallNotify:false];

    NSException *ex = [[NSException alloc] initWithName:@"myName" reason:@"myReason1" userInfo:nil];

    __block NSString *eventErrorClass;
    __block NSString *eventErrorMessage;
    __block BOOL eventUnhandled;
    __block NSString *eventSeverity;

    // Check that the event is passed the apiKey
    [client notify:ex block:^BOOL(RSCrashReporterEvent * _Nonnull event) {
        XCTAssertEqualObjects(event.apiKey, DUMMY_APIKEY_32CHAR_1);

        // Grab the values that end up in the event for later comparison
        eventErrorClass = event.errors[0].errorClass;
        eventErrorMessage = event.errors[0].errorMessage;
        eventUnhandled = [event valueForKeyPath:@"handledState.unhandled"] ? YES : NO;
        eventSeverity = RSCFormatSeverity([event severity]);
        return true;
    }];

    // Check that we can change it
    [client notify:ex];

    NSDictionary *breadcrumb = [client.breadcrumbs.lastObject objectValue];
    NSDictionary *metadata = [breadcrumb valueForKey:@"metaData"];

    XCTAssertEqualObjects([breadcrumb valueForKey:@"type"], @"error");
    XCTAssertEqualObjects([breadcrumb valueForKey:@"name"], eventErrorClass);
    XCTAssertEqualObjects([metadata valueForKey:@"errorClass"], eventErrorClass);
    XCTAssertEqualObjects([metadata valueForKey:@"name"], eventErrorMessage);
    XCTAssertEqual((bool)[metadata valueForKey:@"unhandled"], eventUnhandled);
    XCTAssertEqualObjects([metadata valueForKey:@"severity"], eventSeverity);
}

/**
 * Test that Client inherits metadata from Configuration on init()
 */
- (void) testClientConfigurationHaveSeparateMetadata {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [configuration addMetadata:@{@"exampleKey" : @"exampleValue"} toSection:@"exampleSection"];

    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
    [client start];

    // We expect that the client metadata is the same as the configuration's to start with
    XCTAssertEqualObjects([client getMetadataFromSection:@"exampleSection" withKey:@"exampleKey"],
                          [configuration getMetadataFromSection:@"exampleSection" withKey:@"exampleKey"]);
    XCTAssertNil([client getMetadataFromSection:@"aSection" withKey:@"foo"]);
    [client addMetadata:@{@"foo" : @"bar"} withKey:@"aDict" toSection:@"aSection"];
    XCTAssertNotNil([client getMetadataFromSection:@"aSection" withKey:@"aDict"]);

    // Updates to Configuration should not affect Client
    [configuration addMetadata:@{@"exampleKey2" : @"exampleValue2"} toSection:@"exampleSection2"];
    XCTAssertNil([client getMetadataFromSection:@"exampleSection2" withKey:@"exampleKey2"]);

    // Updates to Client should not affect Configuration
    [client addMetadata:@{@"exampleKey3" : @"exampleValue3"} toSection:@"exampleSection3"];
    XCTAssertNil([configuration getMetadataFromSection:@"exampleSection3" withKey:@"exampleKey3"]);
}
/*
- (void)testMissingApiKey {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:@""];
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
    XCTAssertThrowsSpecificNamed([client start], NSException, NSInvalidArgumentException,
                                 @"An empty apiKey should cause [RSCrashReporterClient start] to throw an exception.");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    configuration.apiKey = nil;
#pragma clang diagnostic pop
    XCTAssertThrowsSpecificNamed([client start], NSException, NSInvalidArgumentException,
                                 @"A missing apiKey should cause [RSCrashReporterClient start] to throw an exception.");
}
*/
- (void)testInvalidApiKey {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:@"INVALID-API-KEY"];
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
    XCTAssertNoThrow([client start], @"[RSCrashReporterClient start] should not throw an exception if the apiKey appears to be malformed");
}

/**
 * Test that user info is stored and retreived correctly
 */
- (void) testUserInfoStorageRetrieval {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
    [client start];

    [client setUser:@"Jiminy" withEmail:@"jiminy@bugsnag.com" andName:@"Jiminy Cricket"];

    XCTAssertNil([client.metadata getMetadataFromSection:RSCKeyUser withKey:RSCKeyId], @"Jiminy");
    XCTAssertNil([client.metadata getMetadataFromSection:RSCKeyUser withKey:RSCKeyName], @"Jiminy Cricket");
    XCTAssertNil([client.metadata getMetadataFromSection:RSCKeyUser withKey:RSCKeyEmail], @"jiminy@bugsnag.com");

    XCTAssertEqualObjects([client user].id, @"Jiminy");
    XCTAssertEqualObjects([client user].name, @"Jiminy Cricket");
    XCTAssertEqualObjects([client user].email, @"jiminy@bugsnag.com");

    [client setUser:nil withEmail:nil andName:@"Jiminy Cricket"];

    XCTAssertNil([client user].id);
    XCTAssertEqualObjects([client user].name, @"Jiminy Cricket");
    XCTAssertNil([client user].email);
}

- (void)testMetadataMutability {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
    [client start];

    // Immutable in, mutable out
    [client addMetadata:@{@"foo" : @"bar"} toSection:@"section1"];
    NSObject *metadata1 = [client getMetadataFromSection:@"section1"];
    XCTAssertTrue([metadata1 isKindOfClass:[NSMutableDictionary class]]);

    // Mutable in, mutable out
    [client addMetadata:[@{@"foo" : @"bar"} mutableCopy] toSection:@"section2"];
    NSObject *metadata2 = [client getMetadataFromSection:@"section2"];
    XCTAssertTrue([metadata2 isKindOfClass:[NSMutableDictionary class]]);
}

/**
 * Helper for asserting two RSCrashReporterConfiguration objects are equal
 */
- (void)assertEqualConfiguration:(RSCrashReporterConfiguration *)expected withActual:(RSCrashReporterConfiguration *)actual {
    XCTAssertEqualObjects(expected.apiKey, actual.apiKey);
    XCTAssertEqualObjects(expected.appType, actual.appType);
    XCTAssertEqualObjects(expected.appVersion, actual.appVersion);
    XCTAssertEqual(expected.autoDetectErrors, actual.autoDetectErrors);
    XCTAssertEqual(expected.autoTrackSessions, actual.autoTrackSessions);
    XCTAssertEqualObjects(expected.bundleVersion, actual.bundleVersion);
    XCTAssertEqual(expected.context, actual.context);
    XCTAssertEqual(expected.enabledBreadcrumbTypes, actual.enabledBreadcrumbTypes);
    XCTAssertEqual(expected.enabledErrorTypes.cppExceptions, actual.enabledErrorTypes.cppExceptions);
    XCTAssertEqual(expected.enabledErrorTypes.unhandledExceptions, actual.enabledErrorTypes.unhandledExceptions);
    XCTAssertEqual(expected.enabledErrorTypes.unhandledRejections, actual.enabledErrorTypes.unhandledRejections);
    XCTAssertEqual(expected.enabledReleaseStages, actual.enabledReleaseStages);
    XCTAssertEqualObjects(expected.endpoints.notify, actual.endpoints.notify);
    XCTAssertEqualObjects(expected.endpoints.sessions, actual.endpoints.sessions);
    XCTAssertEqual(expected.maxPersistedEvents, actual.maxPersistedEvents);
    XCTAssertEqual(expected.maxPersistedSessions, actual.maxPersistedSessions);
    XCTAssertEqual(expected.maxBreadcrumbs, actual.maxBreadcrumbs);
    XCTAssertEqual(expected.persistUser, actual.persistUser);
    XCTAssertEqual([expected.redactedKeys count], [actual.redactedKeys count]);
    XCTAssertEqualObjects([expected.redactedKeys allObjects][0], [actual.redactedKeys allObjects][0]);
    XCTAssertEqualObjects(expected.releaseStage, actual.releaseStage);
#if !TARGET_OS_WATCH
    XCTAssertEqual(expected.enabledErrorTypes.machExceptions, actual.enabledErrorTypes.machExceptions);
    XCTAssertEqual(expected.enabledErrorTypes.signals, actual.enabledErrorTypes.signals);
    XCTAssertEqual(expected.enabledErrorTypes.ooms, actual.enabledErrorTypes.ooms);
    XCTAssertEqual(expected.sendThreads, actual.sendThreads);
#endif
}

/**
 * After starting RSCrashReporter, any changes to the supplied Configuration should be ignored
 * Instead it should be changed by mutating the returned Configuration from "[RSCrashReporter configuration]"
 */
- (void)testChangesToConfigurationAreIgnoredAfterCallingStart {
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    // Take a copy of our Configuration object so we can compare with it later
    RSCrashReporterConfiguration *initialConfig = [config copy];

    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:config delegate:nil];
    [client start];

    // Modify some arbitrary properties
    config.persistUser = !config.persistUser;
    config.maxPersistedEvents = config.maxPersistedEvents * 2;
    config.maxPersistedSessions = config.maxPersistedSessions * 2;
    config.maxBreadcrumbs = config.maxBreadcrumbs * 2;
    config.appVersion = @"99.99.99";

    // Ensure the changes haven't been reflected in our copy
    XCTAssertNotEqual(initialConfig.persistUser, config.persistUser);
    XCTAssertNotEqual(initialConfig.maxPersistedEvents, config.maxPersistedEvents);
    XCTAssertNotEqual(initialConfig.maxPersistedSessions, config.maxPersistedSessions);
    XCTAssertNotEqual(initialConfig.maxBreadcrumbs, config.maxBreadcrumbs);
    XCTAssertNotEqualObjects(initialConfig.appVersion, config.appVersion);

    RSCrashReporterConfiguration *configAfter = client.configuration;

    [self assertEqualConfiguration:initialConfig withActual:configAfter];
}
/*
- (void)testStartingRSCrashReporterTwiceLogsAWarningAndIgnoresNewConfiguration {
    [RSCrashReporter startWithApiKey:DUMMY_APIKEY_32CHAR_1];
    RSCrashReporterConfiguration *initialConfig = RSCrashReporter.client.configuration;

    // Create a new Configuration object and modify some arbitrary properties
    // These updates should all be ignored as RSCrashReporter has been started already
    RSCrashReporterConfiguration *updatedConfig = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_2];
    updatedConfig.persistUser = !initialConfig.persistUser;
    updatedConfig.maxBreadcrumbs = initialConfig.maxBreadcrumbs * 2;
    updatedConfig.maxPersistedEvents = initialConfig.maxPersistedEvents * 2;
    updatedConfig.maxPersistedSessions = initialConfig.maxPersistedSessions * 2;
    updatedConfig.appVersion = @"99.99.99";

    [RSCrashReporter startWithConfiguration:updatedConfig];

    RSCrashReporterConfiguration *configAfter = RSCrashReporter.client.configuration;

    [self assertEqualConfiguration:initialConfig withActual:configAfter];
}*/

/**
 * Verifies that a large breadcrumb is not dropped (historically there was a 4kB limit)
 */
- (void)testLargeBreadcrumbSize {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    configuration.enabledBreadcrumbTypes = RSCEnabledBreadcrumbTypeNone;
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
    [client start];

    XCTAssertEqual(client.breadcrumbs.count, 0);

    // small breadcrumb can be left without issue
    [client leaveBreadcrumbWithMessage:@"Hello World"];
    XCTAssertEqual(client.breadcrumbs.count, 1);

    // large breadcrumb is also left without issue
    __block NSUInteger crumbSize = 0;
    __block RSCrashReporterBreadcrumb *crumb;

    [client addOnBreadcrumbBlock:^BOOL(RSCrashReporterBreadcrumb *breadcrumb) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:[breadcrumb objectValue] options:0 error:nil];
        crumbSize = data.length;
        crumb = breadcrumb;
        return true;
    }];

    NSDictionary *largeMetadata = [self generateLargeMetadata];
    [client leaveBreadcrumbWithMessage:@"Hello World"
                              metadata:largeMetadata
                               andType:RSCBreadcrumbTypeManual];
    XCTAssertTrue(crumbSize > 4096); // previous 4kb limit
    XCTAssertEqual(client.breadcrumbs.count, 2);
    XCTAssertNotNil(crumb);
    XCTAssertEqualObjects(@"Hello World", crumb.message);
    XCTAssertEqualObjects(largeMetadata, crumb.metadata);
}

- (void)testMetadataInvalidKey {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    configuration.enabledBreadcrumbTypes = RSCEnabledBreadcrumbTypeNone;
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:configuration delegate:nil];
    [client start];

    id badMetadata = @{
        @"test": @"string key is fine",
        @85 : @"numeric key would break JSON"
    };

    [client notifyError:[NSError errorWithDomain:@"test" code:0 userInfo:badMetadata]];
}

- (NSDictionary *)generateLargeMetadata {
    NSMutableDictionary *dict = [NSMutableDictionary new];

    for (int k = 0; k < 10000; ++k) {
        NSString *key = [NSString stringWithFormat:@"%d", k];
        NSString *value = [NSString stringWithFormat:@"Some metadata value here %d", k];
        dict[key] = value;
    }
    return dict;
}

@end
