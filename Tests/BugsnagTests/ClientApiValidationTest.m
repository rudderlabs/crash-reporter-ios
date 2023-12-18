//
//  ClientApiValidationTest.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 10/06/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
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
    self.client = [[RSCrashReporterClient alloc]initWithConfiguration:config delegate:nil];
}

- (void)testValidNotify {
    [self.client notify:[NSException exceptionWithName:@"FooException" reason:@"whoops" userInfo:nil]];
}

- (void)testValidNotifyBlock {
    NSException *exc = [NSException exceptionWithName:@"FooException" reason:@"whoops" userInfo:nil];
    [self.client notify:exc block:nil];
    [self.client notify:exc block:^BOOL(RSCrashReporterEvent *event) {
        return NO;
    }];
}

- (void)testValidNotifyError {
    NSError *error = [NSError errorWithDomain:@"BarError" code:500 userInfo:nil];
    [self.client notifyError:error];
}

- (void)testValidNotifyErrorBlock {
    NSError *error = [NSError errorWithDomain:@"BarError" code:500 userInfo:nil];
    [self.client notifyError:error block:nil];
    [self.client notifyError:error block:^BOOL(RSCrashReporterEvent *event) {
        return NO;
    }];
}

- (void)testValidLeaveBreadcrumbWithMessage {
    [self.client leaveBreadcrumbWithMessage:@"Foo"];
}

- (void)testValidLeaveBreadcrumbForNotificationName {
    [self.client leaveBreadcrumbForNotificationName:@"some invalid value"];
}

- (void)testValidLeaveBreadcrumbWithMessageMetadata {
    [self.client leaveBreadcrumbWithMessage:@"Foo" metadata:nil andType:RSCBreadcrumbTypeProcess];
    [self.client leaveBreadcrumbWithMessage:@"Foo" metadata:@{@"test": @2} andType:RSCBreadcrumbTypeState];
}

- (void)testValidStartSession {
    [self.client startSession];
}

- (void)testValidPauseSession {
    [self.client pauseSession];
}

- (void)testValidResumeSession {
    [self.client resumeSession];
}

- (void)testValidContext {
    self.client.context = nil;
    XCTAssertNil(self.client.context);
    self.client.context = @"Foo";
    XCTAssertEqualObjects(@"Foo", self.client.context);
}

- (void)testValidAppDidCrashLastLaunch {
    XCTAssertFalse(self.client.lastRunInfo.crashed);
}

- (void)testValidUser {
    [self.client setUser:nil withEmail:nil andName:nil];
    XCTAssertNotNil(self.client.user);
    XCTAssertNil(self.client.user.id);
    XCTAssertNil(self.client.user.email);
    XCTAssertNil(self.client.user.name);

    [self.client setUser:@"123" withEmail:@"joe@foo.com" andName:@"Joe"];
    XCTAssertNotNil(self.client.user);
    XCTAssertEqualObjects(@"123", self.client.user.id);
    XCTAssertEqualObjects(@"joe@foo.com", self.client.user.email);
    XCTAssertEqualObjects(@"Joe", self.client.user.name);
}

- (void)testValidOnSessionBlock {
    RSCrashReporterOnSessionRef callback = [self.client addOnSessionBlock:^BOOL(RSCrashReporterSession *session) {
        return NO;
    }];
    [self.client removeOnSession:callback];
}

- (void)testValidOnBreadcrumbBlock {
    RSCrashReporterOnBreadcrumbRef callback = [self.client addOnBreadcrumbBlock:^BOOL(RSCrashReporterBreadcrumb *breadcrumb) {
        return NO;
    }];
    [self.client removeOnBreadcrumb:callback];
}

- (void)testValidAddMetadata {
    [self.client addMetadata:@{} toSection:@"foo"];
    XCTAssertNil([self.client getMetadataFromSection:@"foo"]);

    [self.client addMetadata:nil withKey:@"nom" toSection:@"foo"];
    [self.client addMetadata:@"" withKey:@"bar" toSection:@"foo"];
    XCTAssertNil([self.client getMetadataFromSection:@"foo" withKey:@"nom"]);
    XCTAssertEqualObjects(@"", [self.client getMetadataFromSection:@"foo" withKey:@"bar"]);
}

- (void)testValidClearMetadata {
    [self.client clearMetadataFromSection:@""];
    [self.client clearMetadataFromSection:@"" withKey:@""];
}

- (void)testValidGetMetadata {
    [self.client getMetadataFromSection:@""];
    [self.client getMetadataFromSection:@"" withKey:@""];
}

@end
