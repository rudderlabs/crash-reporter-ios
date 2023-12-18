//
//  RSCDefinesTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 23/06/2022.
//  Copyright © 2022 RSCrashReporter Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCDefines.h"

@interface RSCDefinesTests : XCTestCase

@end

@implementation RSCDefinesTests

- (void)testCoreFoundationVersion {
    if (@available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)) {
        XCTAssertGreaterThanOrEqual(kCFCoreFoundationVersionNumber, kCFCoreFoundationVersionNumber_iOS_12_0);
    } else {
        XCTAssertLessThan(kCFCoreFoundationVersionNumber, kCFCoreFoundationVersionNumber_iOS_12_0);
    }
}

@end
