//
//  BugsnagApiValidationTest.m
//  Bugsnag
//
//  Created by Jamie Lynch on 10/06/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <RSCrashReporter/RSCrashReporter.h>
#import "BugsnagTestConstants.h"
#import "TestSupport.h"

/**
 * Validates that the Bugsnag API interface handles any invalid input gracefully.
 */
@interface BugsnagApiValidationTest : XCTestCase

@end

@implementation BugsnagApiValidationTest

- (void)setUp {
    [TestSupport purgePersistentData];
    [RSCrashReporter startWithDelegate:nil];
}
/*
- (void)testAppDidCrashLastLaunch {
    XCTAssertFalse(Bugsnag.lastRunInfo.crashed);
}
*/
- (void)testValidNotify {
    [RSCrashReporter notify:[NSException exceptionWithName:@"FooException" reason:@"whoops" userInfo:nil]];
}

- (void)testValidNotifyBlock {
    NSException *exc = [NSException exceptionWithName:@"FooException" reason:@"whoops" userInfo:nil];
    [RSCrashReporter notify:exc block:nil];
    [RSCrashReporter notify:exc block:^BOOL(BugsnagEvent *event) {
        return NO;
    }];
}

- (void)testValidNotifyError {
    NSError *error = [NSError errorWithDomain:@"BarError" code:500 userInfo:nil];
    [RSCrashReporter notifyError:error];
}

- (void)testValidNotifyErrorBlock {
    NSError *error = [NSError errorWithDomain:@"BarError" code:500 userInfo:nil];
    [RSCrashReporter notifyError:error block:nil];
    [RSCrashReporter notifyError:error block:^BOOL(BugsnagEvent *event) {
        return NO;
    }];
}

- (void)testValidLeaveBreadcrumbWithMessage {
    [RSCrashReporter leaveBreadcrumbWithMessage:@"Foo"];
}

- (void)testValidLeaveBreadcrumbForNotificationName {
    [RSCrashReporter leaveBreadcrumbForNotificationName:@"some invalid value"];
}

- (void)testValidLeaveBreadcrumbWithMessageMetadata {
    [RSCrashReporter leaveBreadcrumbWithMessage:@"Foo" metadata:nil andType:BSGBreadcrumbTypeProcess];
    [RSCrashReporter leaveBreadcrumbWithMessage:@"Foo" metadata:@{@"test": @2} andType:BSGBreadcrumbTypeState];
}
/*
- (void)testValidStartSession {
    [RSCrashReporter startSession];
}

- (void)testValidPauseSession {
    [RSCrashReporter pauseSession];
}

- (void)testValidResumeSession {
    [RSCrashReporter resumeSession];
}

- (void)testValidContext {
    Bugsnag.context = nil;
    XCTAssertNil(Bugsnag.context);
    Bugsnag.context = @"Foo";
    XCTAssertEqualObjects(@"Foo", Bugsnag.context);
}

- (void)testValidAppDidCrashLastLaunch {
    XCTAssertFalse(Bugsnag.lastRunInfo.crashed);
}

- (void)testValidUser {
    [RSCrashReporter setUser:nil withEmail:nil andName:nil];
    XCTAssertNotNil(Bugsnag.user);
    XCTAssertNil(Bugsnag.user.id);
    XCTAssertNil(Bugsnag.user.email);
    XCTAssertNil(Bugsnag.user.name);

    [RSCrashReporter setUser:@"123" withEmail:@"joe@foo.com" andName:@"Joe"];
    XCTAssertNotNil(Bugsnag.user);
    XCTAssertEqualObjects(@"123", Bugsnag.user.id);
    XCTAssertEqualObjects(@"joe@foo.com", Bugsnag.user.email);
    XCTAssertEqualObjects(@"Joe", Bugsnag.user.name);
}

- (void)testValidOnSessionBlock {
    BugsnagOnSessionRef callback = [RSCrashReporter addOnSessionBlock:^BOOL(BugsnagSession *session) {
        return NO;
    }];
    [RSCrashReporter removeOnSession:callback];
}

- (void)testValidOnBreadcrumbBlock {
    BugsnagOnBreadcrumbRef callback = [RSCrashReporter addOnBreadcrumbBlock:^BOOL(BugsnagBreadcrumb *breadcrumb) {
        return NO;
    }];
    [RSCrashReporter removeOnBreadcrumb:callback];
}
*/
- (void)testValidAddMetadata {
    [RSCrashReporter addMetadata:@{} toSection:@"foo"];
    XCTAssertNil([RSCrashReporter getMetadataFromSection:@"foo"]);

    [RSCrashReporter addMetadata:nil withKey:@"nom" toSection:@"foo"];
    [RSCrashReporter addMetadata:@"" withKey:@"bar" toSection:@"foo"];
    XCTAssertNil([RSCrashReporter getMetadataFromSection:@"foo" withKey:@"nom"]);
    XCTAssertEqualObjects(@"", [RSCrashReporter getMetadataFromSection:@"foo" withKey:@"bar"]);
}

- (void)testValidClearMetadata {
    [RSCrashReporter clearMetadataFromSection:@""];
    [RSCrashReporter clearMetadataFromSection:@"" withKey:@""];
}

- (void)testValidGetMetadata {
    [RSCrashReporter getMetadataFromSection:@""];
    [RSCrashReporter getMetadataFromSection:@"" withKey:@""];
}

@end
