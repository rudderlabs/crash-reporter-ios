//
//  RSCSerializationTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 28/07/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCSerialization.h"

@interface RSCSerializationTests : XCTestCase

@end

@implementation RSCSerializationTests

- (void)testSanitizeObject {
    XCTAssertEqualObjects(RSCSanitizeObject(@""), @"");
    XCTAssertEqualObjects(RSCSanitizeObject(@42), @42);
    XCTAssertEqualObjects(RSCSanitizeObject(@[@42]), @[@42]);
    XCTAssertEqualObjects(RSCSanitizeObject(@[self]), @[]);
    XCTAssertEqualObjects(RSCSanitizeObject(@{@"a": @"b"}), @{@"a": @"b"});
    XCTAssertEqualObjects(RSCSanitizeObject(@{@"self": self}), @{});
    XCTAssertNil(RSCSanitizeObject(@(INFINITY)));
    XCTAssertNil(RSCSanitizeObject(@(NAN)));
    XCTAssertNil(RSCSanitizeObject([NSDate date]));
    XCTAssertNil(RSCSanitizeObject([NSDecimalNumber notANumber]));
    XCTAssertNil(RSCSanitizeObject([NSNull null]));
    XCTAssertNil(RSCSanitizeObject(self));
}

- (void)testTruncateString {
    RSCTruncateContext context = {0};
    
    context.maxLength = NSUIntegerMax;
    XCTAssertEqualObjects(RSCTruncateString(&context, @"Hello, world!"), @"Hello, world!");
    XCTAssertEqual(context.strings, 0);
    XCTAssertEqual(context.length, 0);
    
    context.maxLength = 5;
    XCTAssertEqualObjects(RSCTruncateString(&context, @"Hello, world!"), @"Hello"
                          "\n***8 CHARS TRUNCATED***");
    XCTAssertEqual(context.strings, 1);
    XCTAssertEqual(context.length, 8);
    
    // Verify that emoji (composed character sequences) are not partially truncated
    // Note when adding tests that older OSes like iOS 9 don't understand more recently
    // added emoji like 🏴󠁧󠁢󠁥󠁮󠁧󠁿 and 👩🏾‍🚀 and therefore won't be able to avoid slicing them.
    
    context.maxLength = 10;
    XCTAssertEqualObjects(RSCTruncateString(&context, @"Emoji: 👍🏾"), @"Emoji: "
                          "\n***4 CHARS TRUNCATED***");
    XCTAssertEqual(context.strings, 2);
    XCTAssertEqual(context.length, 12);
}

- (void)testTruncateStringsWithString {
    RSCTruncateContext context = (RSCTruncateContext){.maxLength = 3};
    XCTAssertEqualObjects(RSCTruncateStrings(&context, @"foo bar"), @"foo"
                          "\n***4 CHARS TRUNCATED***");
    XCTAssertEqual(context.strings, 1);
    XCTAssertEqual(context.length, 4);
}

- (void)testTruncateStringsWithArray {
    RSCTruncateContext context = (RSCTruncateContext){.maxLength = 3};
    XCTAssertEqualObjects(RSCTruncateStrings(&context, @[@"foo bar"]),
                          @[@"foo"
                            "\n***4 CHARS TRUNCATED***"]);
    XCTAssertEqual(context.strings, 1);
    XCTAssertEqual(context.length, 4);
}

- (void)testTruncateStringsWithObject {
    RSCTruncateContext context = (RSCTruncateContext){.maxLength = 3};
    XCTAssertEqualObjects(RSCTruncateStrings(&context, @{@"name": @"foo bar"}),
                          @{@"name": @"foo"
                            "\n***4 CHARS TRUNCATED***"});
    XCTAssertEqual(context.strings, 1);
    XCTAssertEqual(context.length, 4);
}

- (void)testTruncateStringsWithNestedObjects {
    RSCTruncateContext context = (RSCTruncateContext){.maxLength = 3};
    XCTAssertEqualObjects(RSCTruncateStrings(&context, (@{@"one": @{@"key": @"foo bar"},
                                                          @"two": @{@"foo": @"Baa, Baa, Black Sheep"}})),
                          (@{@"one": @{@"key": @"foo"
                                       "\n***4 CHARS TRUNCATED***"},
                             @"two": @{@"foo": @"Baa"
                                       "\n***18 CHARS TRUNCATED***"}}));
    XCTAssertEqual(context.strings, 2);
    XCTAssertEqual(context.length, 22);
}

@end
