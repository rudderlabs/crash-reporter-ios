//
//  RSCrashReporterSessionTrackerTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCrashReporterUser.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterSession+Private.h"
#import "RSCrashReporterSessionTracker.h"
#import "RSCrashReporterTestConstants.h"
#import "RSCDefines.h"
#import "RSCWatchKit.h"

@interface RSCrashReporterSessionTrackerTest : XCTestCase
@property RSCrashReporterConfiguration *configuration;
@property RSCrashReporterSessionTracker *sessionTracker;
@property RSCrashReporterUser *user;
@end

@implementation RSCrashReporterSessionTrackerTest

- (void)setUp {
    [super setUp];
    self.configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    self.sessionTracker = [[RSCrashReporterSessionTracker alloc] initWithConfig:self.configuration client:nil];
}

- (void)testStartNewSession {
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSession];
    RSCrashReporterSession *session = self.sessionTracker.runningSession;
    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
}

- (void)testStartNewSessionWithUser {
    [self.configuration setUser:@"123" withEmail:nil andName:@"Bill"];
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSession];
    RSCrashReporterSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
}

- (void)testStartNewAutoCapturedSession {
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    RSCrashReporterSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertNil(session.user.name);
    XCTAssertNil(session.user.id);
    XCTAssertNil(session.user.email);
}

- (void)testStartNewAutoCapturedSessionWithUser {
    [self.configuration setUser:@"123" withEmail:@"bill@example.com" andName:@"Bill"];
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    RSCrashReporterSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
}

- (void)testStartNewAutoCapturedSessionWithAutoCaptureDisabled {
    XCTAssertNil(self.sessionTracker.runningSession);
    self.configuration.autoTrackSessions = NO;
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    RSCrashReporterSession *session = self.sessionTracker.runningSession;

    XCTAssertNil(session);
}

- (void)testUniqueSessionIds {
    [self.sessionTracker startNewSession];
    RSCrashReporterSession *firstSession = self.sessionTracker.runningSession;

    [self.sessionTracker startNewSession];

    RSCrashReporterSession *secondSession = self.sessionTracker.runningSession;
    XCTAssertNotEqualObjects(firstSession.id, secondSession.id);
}

- (void)testIncrementCounts {

    [self.sessionTracker startNewSession];
    [self.sessionTracker incrementEventCountUnhandled:NO];
    [self.sessionTracker incrementEventCountUnhandled:NO];

    RSCrashReporterSession *session = self.sessionTracker.runningSession;
    XCTAssertNotNil(session);
    XCTAssertEqual(2, session.handledCount);
    XCTAssertEqual(0, session.unhandledCount);

    [self.sessionTracker startNewSession];

    session = self.sessionTracker.runningSession;
    XCTAssertEqual(0, session.handledCount);
    XCTAssertEqual(0, session.unhandledCount);

    [self.sessionTracker incrementEventCountUnhandled:YES];
    XCTAssertEqual(0, session.handledCount);
    XCTAssertEqual(1, session.unhandledCount);

    [self.sessionTracker incrementEventCountUnhandled:NO];
    XCTAssertEqual(1, session.handledCount);
    XCTAssertEqual(1, session.unhandledCount);
}

- (void)testOnSendBlockFalse {
    self.configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [self.configuration addOnSessionBlock:^BOOL(RSCrashReporterSession *sessionPayload) {
        return NO;
    }];
    self.sessionTracker = [[RSCrashReporterSessionTracker alloc] initWithConfig:self.configuration client:nil];
    [self.sessionTracker startNewSession];
    XCTAssertNil(self.sessionTracker.currentSession);
}

- (void)testOnSendBlockTrue {
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Session block is invoked"];

    self.configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [self.configuration addOnSessionBlock:^BOOL(RSCrashReporterSession *sessionPayload) {
        [expectation fulfill];
        return YES;
    }];
    self.sessionTracker = [[RSCrashReporterSessionTracker alloc] initWithConfig:self.configuration client:nil];
    [self.sessionTracker startNewSession];
    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertNotNil(self.sessionTracker.currentSession);
}

- (void)testHandleAppForegroundEvent {
    [self.sessionTracker handleAppForegroundEvent];
    XCTAssertNotNil(self.sessionTracker.runningSession, @"There should be a running session after calling handleAppForegroundEvent");

    NSString *sessionId = [self.sessionTracker.runningSession.id copy];
    [self.sessionTracker handleAppForegroundEvent];
    XCTAssertEqualObjects(self.sessionTracker.runningSession.id, sessionId, @"A new session should not be started if previous session did not end");
}

- (void)testStartInBackground {
    [self.sessionTracker startWithNotificationCenter:NSNotificationCenter.defaultCenter isInForeground:NO];
    XCTAssertNil(self.sessionTracker.runningSession, @"There should be no running session after starting tracker in background");
#if TARGET_OS_WATCH
    [NSNotificationCenter.defaultCenter postNotificationName:WKApplicationDidBecomeActiveNotification object:nil];
#elif TARGET_OS_OSX
    [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationDidBecomeActiveNotification object:nil];
#else
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
#endif
    XCTAssertNotNil(self.sessionTracker.runningSession, @"There should be a running session after receiving didBecomeActiveNotification");
}

- (void)testStartInForeground {
    [self.sessionTracker startWithNotificationCenter:NSNotificationCenter.defaultCenter isInForeground:YES];
    XCTAssertNotNil(self.sessionTracker.runningSession, @"There should be a running session after starting tracker in foreground");
}

@end
