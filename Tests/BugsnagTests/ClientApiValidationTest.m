//
//  ClientApiValidationTest.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 10/06/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <RSCrashReporter/RSCrashReporter.h>
#import "RSCrashReporterTestConstants.h"

/**
* Validates that the Client API interface handles any invalid input gracefully.
*/
@interface ClientApiValidationTest : XCTestCase
@property RSCrashReporterClient *client;
@end

@implementation ClientApiValidationTest

- (void)setUp {
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config addOnSendErrorBlock:^BOOL(RSCrashReporterEvent *event) {
        return NO;
    }];
    [RSCrashReporter startWithDelegate:nil];
}

- (void)testValidNotify {
    [RSCrashReporter notify:[NSException exceptionWithName:@"FooException" reason:@"whoops" userInfo:nil]];
}

- (void)testValidNotifyBlock {
    NSException *exc = [NSException exceptionWithName:@"FooException" reason:@"whoops" userInfo:nil];
    [RSCrashReporter notify:exc block:nil];
    [RSCrashReporter notify:exc block:^BOOL(RSCrashReporterEvent *event) {
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
    [RSCrashReporter notifyError:error block:^BOOL(RSCrashReporterEvent *event) {
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
    [RSCrashReporter leaveBreadcrumbWithMessage:@"Foo" metadata:nil andType:RSCBreadcrumbTypeProcess];
    [RSCrashReporter leaveBreadcrumbWithMessage:@"Foo" metadata:@{@"test": @2} andType:RSCBreadcrumbTypeState];
}

- (void)testValidStartSession {
    [RSCrashReporter startSession];
}

- (void)testValidPauseSession {
    [RSCrashReporter pauseSession];
}

- (void)testValidResumeSession {
    [RSCrashReporter resumeSession];
}

/**
 // MARK: - Rudder Commented
 Not needed for us as the relevant logic is commented out.
 */

//- (void)testValidContext {
//    RSCrashReporter.context = nil;
//    XCTAssertNil(RSCrashReporter.context);
//    RSCrashReporter.context = @"Foo";
//    XCTAssertEqualObjects(@"Foo", RSCrashReporter.context);
//}

- (void)testValidAppDidCrashLastLaunch {
    XCTAssertFalse(RSCrashReporter.lastRunInfo.crashed);
}

/**
 // MARK: - Rudder Commented
 Not needed for us as the relevant logic is commented out.
 */
//- (void)testValidUser {
//    [RSCrashReporter setUser:nil withEmail:nil andName:nil];
//    XCTAssertNotNil(RSCrashReporter.user);
//    XCTAssertNil(RSCrashReporter.user.id);
//    XCTAssertNil(RSCrashReporter.user.email);
//    XCTAssertNil(RSCrashReporter.user.name);
//
//    [RSCrashReporter setUser:@"123" withEmail:@"joe@foo.com" andName:@"Joe"];
//    XCTAssertNotNil(RSCrashReporter.user);
//    XCTAssertEqualObjects(@"123", RSCrashReporter.user.id);
//    XCTAssertEqualObjects(@"joe@foo.com", RSCrashReporter.user.email);
//    XCTAssertEqualObjects(@"Joe", RSCrashReporter.user.name);
//}

- (void)testValidOnSessionBlock {
    RSCrashReporterOnSessionRef callback = [RSCrashReporter addOnSessionBlock:^BOOL(RSCrashReporterSession *session) {
        return NO;
    }];
    [RSCrashReporter removeOnSession:callback];
}

- (void)testValidOnBreadcrumbBlock {
    RSCrashReporterOnBreadcrumbRef callback = [RSCrashReporter addOnBreadcrumbBlock:^BOOL(RSCrashReporterBreadcrumb *breadcrumb) {
        return NO;
    }];
    [RSCrashReporter removeOnBreadcrumb:callback];
}

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
