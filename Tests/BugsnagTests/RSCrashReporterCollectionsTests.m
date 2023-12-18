//
//  RSCrashReporterCollectionsTests.m
//  Tests
//
//  Created by Paul Zabelin on 7/1/19.
//  Copyright © 2019 RSCrashReporter. All rights reserved.
//

@import XCTest;
#import "RSCrashReporterCollections.h"

@interface RSCrashReporterCollectionsTests : XCTestCase
@end

@interface RSCrashReporterCollectionsTests_DummyObject : NSObject
@end

@implementation RSCrashReporterCollectionsTests

// MARK: RSCDictMergeTest

- (void)testSubarrayFromIndex {
    XCTAssertEqualObjects(RSCArraySubarrayFromIndex(@[@"foo", @"bar"], 0), (@[@"foo", @"bar"]));
    XCTAssertEqualObjects(RSCArraySubarrayFromIndex(@[@"foo", @"bar"], 1), @[@"bar"]);
    XCTAssertEqualObjects(RSCArraySubarrayFromIndex(@[@"foo", @"bar"], 2), @[]);
    XCTAssertEqualObjects(RSCArraySubarrayFromIndex(@[@"foo", @"bar"], 42), @[]);
    XCTAssertEqualObjects(RSCArraySubarrayFromIndex(@[@"foo", @"bar"], -1), @[]);
}

- (void)testBasicMerge {
    NSDictionary *combined = @{@"a": @"one",
                               @"b": @"two"};
    XCTAssertEqualObjects(combined, RSCDictMerge(@{@"a": @"one"}, @{@"b": @"two"}), @"should combine");
}

- (void)testOverwrite {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, RSCDictMerge(src, @{@"a": @"two"}), @"should overwrite");
}

- (void)testSrcEmpty {
    id dst = @{@"b": @"two"};
    XCTAssertEqualObjects(dst, RSCDictMerge(@{}, dst), @"should copy");
}

- (void)testDstEmpty {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, RSCDictMerge(src, @{}), @"should copy");
}

- (void)testDstNil {
    id src = @{@"a": @"one"};
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertEqualObjects(src, RSCDictMerge(src, nil), @"should copy");
#pragma clang diagnostic pop
}

- (void)testSrcDict {
    id src = @{@"a": @{@"x": @"blah"}};
    XCTAssertEqualObjects(src, RSCDictMerge(src, @{@"a": @"two"}), @"should not overwrite");
}

- (void)testDstDict {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, RSCDictMerge(src, @{@"a": @{@"x": @"blah"}}), @"should not overwrite");
}

- (void)testSrcDstDict {
    id src = @{@"a": @{@"x": @"blah"}};
    id dst = @{@"a": @{@"y": @"something"}};
    NSDictionary* expected = @{@"a": @{@"x": @"blah",
                                       @"y": @"something"}};
    XCTAssertEqualObjects(expected, RSCDictMerge(src, dst), @"should combine");
}

// MARK: RSCJSONDictionary

- (void)testRSCJSONDictionary {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil(RSCJSONDictionary(nil));
#pragma clang diagnostic pop

    id validDictionary = @{
        @"name": @"foobar",
        @"count": @1,
        @"userInfo": @{@"extra": @"hello"}
    };
    XCTAssertEqualObjects(RSCJSONDictionary(validDictionary), validDictionary);
    
    id invalidDictionary = @{
        @123: @"invalid key; should be ignored",
        @[]: @"this is backwards",
        @{}: @""
    };
    XCTAssertEqualObjects(RSCJSONDictionary(invalidDictionary), @{});
    
    id mixedDictionary = @{
        @"count": @42,
        @"dict": @{@"object": [[RSCrashReporterCollectionsTests_DummyObject alloc] init]},
        @123: @"invalid key; should be ignored"
    };
    XCTAssertEqualObjects(RSCJSONDictionary(mixedDictionary),
                          (@{@"count": @42,
                             @"dict": @{@"object": @"Dummy object"}}));
}

@end

// MARK: -

@implementation RSCrashReporterCollectionsTests_DummyObject

- (NSString *)description {
    return @"Dummy object";
}

@end
