//
//  RSCrashReporterHandledStateTest.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 21/09/2017.
//  Copyright © 2017 RSCrashReporter. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <RSCrashReporter/RSCrashReporter.h>
#import "RSCrashReporterHandledState.h"

@interface RSCrashReporterHandledStateTest : XCTestCase

@end

@implementation RSCrashReporterHandledStateTest

- (void)testUnhandledException {
    RSCrashReporterHandledState *state =
    [RSCrashReporterHandledState handledStateWithSeverityReason:UnhandledException];
    XCTAssertNotNil(state);
    XCTAssertTrue(state.unhandled);
    XCTAssertEqual(RSCSeverityError, state.currentSeverity);
    XCTAssertNil(state.attrValue);
    XCTAssertNil(state.attrKey);
}

- (void)testLogMessage {
    RSCrashReporterHandledState *state =
    [RSCrashReporterHandledState handledStateWithSeverityReason:LogMessage
                                               severity:RSCSeverityInfo
                                              attrValue:@"info"];
    XCTAssertNotNil(state);
    XCTAssertFalse(state.unhandled);
    XCTAssertEqual(RSCSeverityInfo, state.currentSeverity);
    XCTAssertEqualObjects(@"info", state.attrValue);
    XCTAssertEqualObjects(@"level", state.attrKey);
}

- (void)testHandledException {
    RSCrashReporterHandledState *state =
    [RSCrashReporterHandledState handledStateWithSeverityReason:HandledException];
    XCTAssertNotNil(state);
    XCTAssertFalse(state.unhandled);
    XCTAssertEqual(RSCSeverityWarning, state.currentSeverity);
    XCTAssertNil(state.attrValue);
    XCTAssertNil(state.attrKey);
}

- (void)testUserSpecified {
    RSCrashReporterHandledState *state = [RSCrashReporterHandledState
                                  handledStateWithSeverityReason:UserSpecifiedSeverity
                                  severity:RSCSeverityInfo
                                  attrValue:nil];
    XCTAssertNotNil(state);
    XCTAssertFalse(state.unhandled);
    XCTAssertEqual(RSCSeverityInfo, state.currentSeverity);
    XCTAssertNil(state.attrValue);
    XCTAssertNil(state.attrKey);
}

- (void)testCallbackSpecified {
    RSCrashReporterHandledState *state =
    [RSCrashReporterHandledState handledStateWithSeverityReason:HandledException];
    XCTAssertEqual(HandledException, state.calculateSeverityReasonType);
    
    state.currentSeverity = RSCSeverityInfo;
    XCTAssertEqual(UserCallbackSetSeverity, state.calculateSeverityReasonType);
    XCTAssertNil(state.attrValue);
    XCTAssertNil(state.attrKey);
}

- (void)testHandledError {
    RSCrashReporterHandledState *state =
    [RSCrashReporterHandledState handledStateWithSeverityReason:HandledError
                                               severity:RSCSeverityWarning
                                              attrValue:@"Test"];
    XCTAssertNotNil(state);
    XCTAssertFalse(state.unhandled);
    XCTAssertEqual(RSCSeverityWarning, state.currentSeverity);
    XCTAssertNil(state.attrValue);
}

- (void)testSignal {
    RSCrashReporterHandledState *state =
    [RSCrashReporterHandledState handledStateWithSeverityReason:Signal
                                               severity:RSCSeverityError
                                              attrValue:@"Test"];
    XCTAssertNotNil(state);
    XCTAssertTrue(state.unhandled);
    XCTAssertEqual(RSCSeverityError, state.currentSeverity);
    XCTAssertEqualObjects(@"Test", state.attrValue);
}

- (void)testPromiseRejection {
    RSCrashReporterHandledState *state =
    [RSCrashReporterHandledState handledStateWithSeverityReason:PromiseRejection];
    XCTAssertNotNil(state);
    XCTAssertTrue(state.unhandled);
    XCTAssertEqual(RSCSeverityError, state.currentSeverity);
    XCTAssertNil(state.attrValue);
}

- (void)testOriginalUnhandled {
    RSCrashReporterHandledState *unhandledState =
    [RSCrashReporterHandledState handledStateWithSeverityReason:PromiseRejection];
    XCTAssertTrue(unhandledState.originalUnhandledValue);
    
    unhandledState.unhandledOverridden = YES;
    XCTAssertFalse(unhandledState.originalUnhandledValue);
    
    RSCrashReporterHandledState *handledState =
    [RSCrashReporterHandledState handledStateWithSeverityReason:HandledError
                                               severity:RSCSeverityWarning
                                              attrValue:@"Test"];
    XCTAssertFalse(handledState.originalUnhandledValue);
    
    handledState.unhandledOverridden = YES;
    XCTAssertTrue(handledState.originalUnhandledValue);
}

@end
