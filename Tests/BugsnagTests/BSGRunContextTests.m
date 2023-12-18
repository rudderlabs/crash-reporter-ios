//
//  RSCRunContextTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 14/07/2022.
//  Copyright © 2022 RSCrashReporter Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCFileLocations.h"
#import "RSCRunContext.h"

@interface RSCRunContextTests : XCTestCase

@end

@implementation RSCRunContextTests

- (void)setUp {
    if (!rsc_runContext) {
        RSCRunContextInit(RSCFileLocations.current.runContext);
    }
}

- (void)testMemory {
    unsigned long long physicalMemory = NSProcessInfo.processInfo.physicalMemory;
    
    XCTAssertGreaterThan(rsc_runContext->hostMemoryFree, 0);
    XCTAssertLessThan   (rsc_runContext->hostMemoryFree, physicalMemory);
    
    XCTAssertGreaterThan(rsc_runContext->memoryFootprint, 0);
    XCTAssertLessThan   (rsc_runContext->memoryFootprint, physicalMemory);
    
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    XCTAssertEqual(rsc_runContext->memoryAvailable, 0);
    XCTAssertEqual(rsc_runContext->memoryLimit, 0);
#else
    if (@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
#if !TARGET_OS_SIMULATOR
        XCTAssertGreaterThan(rsc_runContext->memoryAvailable, 0);
#else
        XCTAssertEqual(rsc_runContext->memoryAvailable, 0);
#endif
        XCTAssertLessThan   (rsc_runContext->memoryAvailable, physicalMemory);
        
        XCTAssertGreaterThan(rsc_runContext->memoryLimit, 0);
        XCTAssertLessThan   (rsc_runContext->memoryLimit, physicalMemory);
    } else {
        XCTAssertEqual(rsc_runContext->memoryAvailable, 0);
        XCTAssertEqual(rsc_runContext->memoryLimit, 0);
    }
#endif
}

@end
