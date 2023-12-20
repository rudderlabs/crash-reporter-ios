//
//  RSCrashReporterNotifierTest.m
//  Tests
//
//  Created by Jamie Lynch on 29/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RSCrashReporterNotifier.h"

@interface RSCrashReporterNotifierTest : XCTestCase
@property RSCrashReporterNotifier *notifier;
@end

@implementation RSCrashReporterNotifierTest

- (void)setUp {
    self.notifier = [RSCrashReporterNotifier new];
    self.notifier.name = @"Foo Notifier";
    self.notifier.version = @"6.0.0";
}

- (void)testDefaultValues {
    self.notifier = [RSCrashReporterNotifier new];
    XCTAssertEqualObjects(@"https://github.com/bugsnag/bugsnag-cocoa", self.notifier.url);
    XCTAssertNotNil(self.notifier.name);
    XCTAssertNotNil(self.notifier.version);
    XCTAssertNotNil(self.notifier.dependencies);
    XCTAssertEqual(0, [self.notifier.dependencies count]);
}

- (void)testSerialization {
    NSDictionary *dict = [self.notifier toDict];
    XCTAssertEqualObjects(@"https://github.com/bugsnag/bugsnag-cocoa", dict[@"url"]);
    XCTAssertEqualObjects(@"Foo Notifier", dict[@"name"]);
    XCTAssertEqualObjects(@"6.0.0", dict[@"version"]);
    XCTAssertNil(dict[@"dependencies"]);
}

- (void)testDependencySerialization {
    RSCrashReporterNotifier *dep = [RSCrashReporterNotifier new];
    dep.name = @"COBOL Notifier";
    dep.version = @"1.0.0";
    dep.url = @"https://github.com/bugsnag/bugsnag-cobol";
    self.notifier.dependencies = @[dep];

    NSDictionary *dict = [self.notifier toDict];
    XCTAssertEqualObjects(@"https://github.com/bugsnag/bugsnag-cocoa", dict[@"url"]);
    XCTAssertEqualObjects(@"Foo Notifier", dict[@"name"]);
    XCTAssertEqualObjects(@"6.0.0", dict[@"version"]);

    NSDictionary *depJson = dict[@"dependencies"][0];
    XCTAssertNotNil(depJson);
    XCTAssertEqualObjects(@"https://github.com/bugsnag/bugsnag-cobol", depJson[@"url"]);
    XCTAssertEqualObjects(@"COBOL Notifier", depJson[@"name"]);
    XCTAssertEqualObjects(@"1.0.0", depJson[@"version"]);
    XCTAssertNil(depJson[@"dependencies"]);
}

@end
