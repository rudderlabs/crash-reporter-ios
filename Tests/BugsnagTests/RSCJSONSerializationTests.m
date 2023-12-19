//
//  RSCJSONSerializationTests.m
//  RSCrashReporter
//
//  Created by Karl Stenerud on 03.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCJSONSerialization.h"

@interface RSCJSONSerializationTests : XCTestCase
@end

@implementation RSCJSONSerializationTests

- (void)testBadJSONKey {
    id badDict = @{@123: @"string"};
    NSData* badJSONData = [@"{123=\"test\"}" dataUsingEncoding:NSUTF8StringEncoding];
    id result;
    NSError* error;
    result = RSCJSONDataFromDictionary(badDict, &error);
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    error = nil;
    
    result = RSCJSONDictionaryFromData(badJSONData, 0, &error);
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    error = nil;
}

- (void)testJSONFileSerialization {
    id validJSON = @{@"foo": @"bar"};
    id invalidJSON = @{@"foo": [NSDate date]};
    
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@(__PRETTY_FUNCTION__)];
    
    XCTAssertTrue(RSCJSONWriteToFileAtomically(validJSON, file, nil));

    XCTAssertEqualObjects(RSCJSONDictionaryFromFile(file, 0, nil), @{@"foo": @"bar"});
    
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    
    NSError *error = nil;
    XCTAssertFalse(RSCJSONWriteToFileAtomically(invalidJSON, file, &error));
    XCTAssertNotNil(error);
    
    error = nil;
    XCTAssertNil(RSCJSONDictionaryFromFile(file, 0, &error));
    XCTAssertNotNil(error);

    NSString *unwritablePath = @"/System/Library/foobar";
    
    error = nil;
    XCTAssertFalse(RSCJSONWriteToFileAtomically(validJSON, unwritablePath, &error));
    XCTAssertNotNil(error);
    
    error = nil;
    XCTAssertNil(RSCJSONDictionaryFromFile(file, 0, &error));
    XCTAssertNotNil(error);
}

- (void)testExceptionHandling {
    NSError *error = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil(RSCJSONDictionaryFromData(nil, 0, &error));
#pragma clang diagnostic pop
    XCTAssertNotNil(error);
    id underlyingError = error.userInfo[NSUnderlyingErrorKey];
    XCTAssert(!underlyingError || [underlyingError isKindOfClass:[NSError class]], @"The value of %@ should be an NSError", NSUnderlyingErrorKey);
}

@end
