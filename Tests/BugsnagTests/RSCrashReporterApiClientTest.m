//
//  RSCrashReporterApiClientTest.m
//  RSCrashReporter-iOSTests
//
//  Created by Karl Stenerud on 04.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RSCrashReporterApiClient.h"
#import <RSCrashReporter/RSCrashReporter.h>
#import "RSCrashReporterTestConstants.h"
#import "URLSessionMock.h"

@interface RSCrashReporterApiClientTest : XCTestCase

@end

@implementation RSCrashReporterApiClientTest

- (void)testHTTPStatusCodes {
    NSURL *url = [NSURL URLWithString:@"https://example.com"];
    id URLSession = [[URLSessionMock alloc] init];
    
    void (^ test)(NSInteger, RSCDeliveryStatus, BOOL) =
    ^(NSInteger statusCode, RSCDeliveryStatus expectedDeliveryStatus, BOOL expectError) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler should be called"];
        id response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode HTTPVersion:@"1.1" headerFields:nil];
        [URLSession mockData:[NSData data] response:response error:nil];
        RSCPostJSONData(URLSession, [NSData data], @{}, url, ^(RSCDeliveryStatus status, NSError * _Nullable error) {
            XCTAssertEqual(status, expectedDeliveryStatus);
            expectError ? XCTAssertNotNil(error) : XCTAssertNil(error);
            [expectation fulfill];
        });
    };
    
    test(200, RSCDeliveryStatusDelivered, NO);
    
    // Permanent failures
    test(400, RSCDeliveryStatusUndeliverable, YES);
    test(401, RSCDeliveryStatusUndeliverable, YES);
    test(403, RSCDeliveryStatusUndeliverable, YES);
    test(404, RSCDeliveryStatusUndeliverable, YES);
    test(405, RSCDeliveryStatusUndeliverable, YES);
    test(406, RSCDeliveryStatusUndeliverable, YES);
    
    // Transient failures
    test(402, RSCDeliveryStatusFailed, YES);
    test(407, RSCDeliveryStatusFailed, YES);
    test(408, RSCDeliveryStatusFailed, YES);
    test(429, RSCDeliveryStatusFailed, YES);
    test(500, RSCDeliveryStatusFailed, YES);
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testNotConnectedToInternetError {
    NSURL *url = [NSURL URLWithString:@"https://example.com"];
    id URLSession = [[URLSessionMock alloc] init];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler should be called"];
    [URLSession mockData:nil response:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:@{
        NSURLErrorFailingURLErrorKey: url,
    }]];
    RSCPostJSONData(URLSession, [NSData data], @{}, url, ^(RSCDeliveryStatus status, NSError * _Nullable error) {
        XCTAssertEqual(status, RSCDeliveryStatusFailed);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSHA1HashStringWithData {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil(RSCIntegrityHeaderValue(nil));
#pragma clang diagnostic pop
    XCTAssertEqualObjects(RSCIntegrityHeaderValue([@"{\"foo\":\"bar\"}" dataUsingEncoding:NSUTF8StringEncoding]), @"sha1 a5e744d0164540d33b1d7ea616c28f2fa97e754a");
}

@end
