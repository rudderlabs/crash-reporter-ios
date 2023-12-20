//
//  RSCrashReporterPluginTest.m
//  Tests
//
//  Created by Jamie Lynch on 12/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCrashReporterTestConstants.h"
#import "RSCrashReporter.h"
#import "RSCrashReporterClient+Private.h"
#import "RSCrashReporterConfiguration+Private.h"

@interface RSCrashReporterPluginTest : XCTestCase

@end

@interface FakePlugin: NSObject<RSCrashReporterPlugin>
@property XCTestExpectation *expectation;
@end
@implementation FakePlugin
    - (void)load:(RSCrashReporterClient *)client {
        [self.expectation fulfill];
    }
    - (void)unload {}
@end

@interface CrashyPlugin: NSObject<RSCrashReporterPlugin>
@property XCTestExpectation *expectation;
@end
@implementation CrashyPlugin
    - (void)load:(RSCrashReporterClient *)client {
        [NSException raise:@"WhoopsException" format:@"something went wrong"];
        [self.expectation fulfill];
    }
    - (void)unload {}
@end

@implementation RSCrashReporterPluginTest

- (void)testAddPlugin {
    id<RSCrashReporterPlugin> plugin = [FakePlugin new];
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config addPlugin:plugin];
    XCTAssertEqual([config.plugins anyObject], plugin);
}

- (void)testPluginLoaded {
    FakePlugin *plugin = [FakePlugin new];
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Plugin Loaded by RSCrashReporter"];
    plugin.expectation = expectation;

    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config addPlugin:plugin];
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:config delegate:nil];
    [client start];
    [self waitForExpectations:@[expectation] timeout:3.0];
}

- (void)testCrashyPluginDoesNotCrashApp {
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Crashy plugin not loaded by RSCrashReporter"];
    expectation.inverted = YES;
    CrashyPlugin *plugin = [CrashyPlugin new];
    plugin.expectation = expectation;

    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config addPlugin:plugin];
    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:config delegate:nil];
    [client start];
    [self waitForExpectations:@[expectation] timeout:3.0];
}

@end
