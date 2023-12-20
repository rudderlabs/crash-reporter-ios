//
//  RSCrashReporterEnabledBreadcrumbTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterTestConstants.h"

@interface RSCrashReporterEnabledBreadcrumbTest : XCTestCase

@end

@implementation RSCrashReporterEnabledBreadcrumbTest

- (void)testEnabledBreadcrumbNone {
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.enabledBreadcrumbTypes = RSCEnabledBreadcrumbTypeNone;
    XCTAssertTrue([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeManual]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeError]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeLog]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeNavigation]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeProcess]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeRequest]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeState]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeUser]);
}

- (void)testEnabledBreadcrumbLog {
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.enabledBreadcrumbTypes = RSCEnabledBreadcrumbTypeLog;
    XCTAssertTrue([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeManual]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeError]);
    XCTAssertTrue([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeLog]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeNavigation]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeProcess]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeRequest]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeState]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeUser]);
}

- (void)testEnabledBreadcrumbMulti {
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.enabledBreadcrumbTypes = RSCEnabledBreadcrumbTypeState | RSCEnabledBreadcrumbTypeNavigation;
    XCTAssertTrue([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeManual]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeError]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeLog]);
    XCTAssertTrue([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeNavigation]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeProcess]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeRequest]);
    XCTAssertTrue([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeState]);
    XCTAssertFalse([config shouldRecordBreadcrumbType:RSCBreadcrumbTypeUser]);
}

@end
