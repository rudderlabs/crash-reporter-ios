//
//  BugsnagSwiftTests.swift
//  Tests
//
//  Created by Robin Macharg on 05/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
//  Swift unit tests of global Bugsnag behaviour

import XCTest

class BugsnagSwiftTests: XCTestCase {

    /**
     * Confirm that the addMetadata() method is exposed to Swift correctly
     */
    func testAddMetadataToSectionIsExposedToSwiftCorrectly() {
        RSCrashReporter.start(with: nil)
        RSCrashReporter.addMetadata("myValue1", key: "myKey1", section: "mySection1")
        
        let exception1 = NSException(name: NSExceptionName(rawValue: "exception1"), reason: "reason1", userInfo: nil)
        
        RSCrashReporter.notify(exception1) { (event) in
            // Arbitrary test, replicating the ObjC one
            let value = event.getMetadata(section: "mySection1", key: "myKey1") as? String
            XCTAssertEqual(value, "myValue1")
            return true
        }
    }
    
    /**
     * Confirm that the clearMetadata() method is exposed to Swift correctly
     */
    func testClearMetadataInSectionIsExposedToSwiftCorrectly() {
        RSCrashReporter.start(with: nil)
        // We don't need to check method's functioning, only that we can call it this way
        RSCrashReporter.clearMetadata(section: "testSection")
   }
    
    /**
     * Confirm that the callback-free methods for leaving metadata are exposed to Swift correctly
     */
    func testCallbackFreeMetadataMethods() {
        RSCrashReporter.leaveBreadcrumb("test2", metadata: nil, type: .manual)
    }
}
