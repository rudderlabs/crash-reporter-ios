//
//  RSCUtilsTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 19/08/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCUtils.h"

@interface RSCUtilsTests : XCTestCase
@end

@implementation RSCUtilsTests

#if TARGET_OS_IOS

- (void)testRSCStringFromDeviceOrientation {
    XCTAssertEqualObjects(RSCStringFromDeviceOrientation(UIDeviceOrientationPortraitUpsideDown), @"portraitupsidedown");
    XCTAssertEqualObjects(RSCStringFromDeviceOrientation(UIDeviceOrientationPortrait), @"portrait");
    XCTAssertEqualObjects(RSCStringFromDeviceOrientation(UIDeviceOrientationLandscapeRight), @"landscaperight");
    XCTAssertEqualObjects(RSCStringFromDeviceOrientation(UIDeviceOrientationLandscapeLeft), @"landscapeleft");
    XCTAssertEqualObjects(RSCStringFromDeviceOrientation(UIDeviceOrientationFaceUp), @"faceup");
    XCTAssertEqualObjects(RSCStringFromDeviceOrientation(UIDeviceOrientationFaceDown), @"facedown");
    XCTAssertNil(RSCStringFromDeviceOrientation(UIDeviceOrientationUnknown));
    XCTAssertNil(RSCStringFromDeviceOrientation(-1));
    XCTAssertNil(RSCStringFromDeviceOrientation(99));
}

#endif

@end
