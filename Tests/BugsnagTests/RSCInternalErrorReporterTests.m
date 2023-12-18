//
//  RSCInternalErrorReporterTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 06/05/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <RSCrashReporter/RSCrashReporter.h>

#import "RSCInternalErrorReporter.h"
#import "RSC_KSSystemInfo.h"
#import "RSCrashReporterAppWithState+Private.h"
#import "RSCrashReporterDeviceWithState+Private.h"
#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterNotifier.h"

@interface RSCInternalErrorReporterTests : XCTestCase

@property (nonatomic) RSCrashReporterConfiguration *configuration;

@end

@implementation RSCInternalErrorReporterTests

- (void)setUp {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [RSCInternalErrorReporter setSharedInstance:nil];
#pragma clang diagnostic pop
    self.configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
}

- (RSCInternalErrorReporter *)makeReporter {
    return [[RSCInternalErrorReporter alloc] initWithApiKey:self.configuration.apiKey endpoint:[NSURL URLWithString:self.configuration.endpoints.notify]];
}

- (void)testEventWithErrorClass {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    RSCInternalErrorReporter *reporter = [self makeReporter];
    
    RSCrashReporterEvent *event = [reporter eventWithErrorClass:@"Internal error" context:@"test" message:@"Something went wrong" diagnostics:@{}];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"Internal error");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"Something went wrong");
    XCTAssertEqualObjects(event.context, @"test");
    XCTAssertEqualObjects(event.threads, @[]);
    XCTAssertEqual(event.errors[0].stacktrace.count, 0);
    XCTAssertNil(event.apiKey);
    
    NSDictionary *diagnostics = [event.metadata getMetadataFromSection:@"RSCrashReporterDiagnostics"];
    XCTAssertEqualObjects(diagnostics[@"apiKey"], configuration.apiKey);
    
//    XCTAssertNotNil(event.device.id);
//    XCTAssertNotEqualObjects(event.device.id, [RSC_KSSystemInfo deviceAndAppHash], @"Internal errors must use a different device id");
}

- (void)testEventWithException {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    RSCInternalErrorReporter *reporter = [self makeReporter];
    
    NSException *exception = nil;
    @try {
        NSLog(@"%@", @[][0]);
    } @catch (NSException *e) {
        exception = e;
    }
    
    RSCrashReporterEvent *event = [reporter eventWithException:exception diagnostics:nil groupingHash:@"test"];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"NSRangeException");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"*** -[__NSArray0 objectAtIndex:]: index 0 beyond bounds for empty array");
    XCTAssertEqualObjects(event.groupingHash, @"test");
    XCTAssertEqualObjects(event.threads, @[]);
    XCTAssertGreaterThan(event.errors[0].stacktrace.count, 0);
    XCTAssertNil(event.apiKey);
    
    NSDictionary *diagnostics = [event.metadata getMetadataFromSection:@"RSCrashReporterDiagnostics"];
    XCTAssertEqualObjects(diagnostics[@"apiKey"], configuration.apiKey);
    
//    XCTAssertNotNil(event.device.id);
//    XCTAssertNotEqualObjects(event.device.id, [RSC_KSSystemInfo deviceAndAppHash], @"Internal errors must use a different device id");
}

- (void)testEventWithRecrashReport {
    RSCrashReporterConfiguration *configuration = [[RSCrashReporterConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    RSCInternalErrorReporter *reporter = [self makeReporter];
    
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"RecrashReport" ofType:@"json" inDirectory:@"Data"];
    id recrashReport = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];
    RSCrashReporterEvent *event = [reporter eventWithRecrashReport:recrashReport];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"Crash handler crashed");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"EXC_BAD_ACCESS");
    XCTAssertEqualObjects(event.errors[0].stacktrace[1].machoUuid, @"77B20495-B09E-3585-AE2C-1475AD41A48A");
    XCTAssertEqualObjects(event.errors[0].stacktrace[1].method, @"BSSerializeDataCrashHandler");
    XCTAssertEqualObjects(event.threads, @[]);
    XCTAssertNil(event.apiKey);
    
//    XCTAssertNotNil(event.device.id);
//    XCTAssertNotEqualObjects(event.device.id, [RSC_KSSystemInfo deviceAndAppHash], @"Internal errors must use a different device id");
    
    NSDictionary *diagnostics = [event.metadata getMetadataFromSection:@"RSCrashReporterDiagnostics"];
    XCTAssertEqualObjects(diagnostics[@"apiKey"], configuration.apiKey);
    XCTAssert([diagnostics[@"crash"] isKindOfClass:[NSDictionary class]]);
    XCTAssert([diagnostics[@"binary_images"] isKindOfClass:[NSArray class]]);
}

- (void)testRequestForEvent {
    self.configuration.endpoints.notify = @"https://notify.example.com";
    
    RSCrashReporterNotifier *notifier = [[RSCrashReporterNotifier alloc] init];
    RSCInternalErrorReporter *reporter = [self makeReporter];

    RSCrashReporterEvent *event = [[RSCrashReporterEvent alloc] init];
    
    NSURLRequest *request = [reporter requestForEvent:event error:NULL];
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:self.configuration.endpoints.notify]);
    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"RSCrashReporter-Internal-Error"], @"bugsnag-cocoa");
    XCTAssertNil([request valueForHTTPHeaderField:@"RSCrashReporter-Api-Key"]);
    XCTAssertNil([request valueForHTTPHeaderField:@"RSCrashReporter-Stacktrace-Types"]);
    XCTAssertNotNil([request valueForHTTPHeaderField:@"RSCrashReporter-Integrity"]);
    XCTAssertNotNil([request valueForHTTPHeaderField:@"RSCrashReporter-Sent-At"]);
    
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:(NSData * _Nonnull)request.HTTPBody options:0 error:NULL];
    XCTAssertEqualObjects(payload[@"events"], @[[event toJsonWithRedactedKeys:nil]]);
    XCTAssertEqualObjects(payload[@"notifier"], [notifier toDict]);
    XCTAssertEqualObjects(payload[@"payloadVersion"], @"4.0");
    XCTAssertNil(payload[@"apiKey"]);
}

- (void)testPerformBlock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"+performBlock: block is called once sharedInstance is set"];
    [RSCInternalErrorReporter performBlock:^(RSCInternalErrorReporter *reporter) {
        XCTAssertNotNil(reporter);
        [expectation fulfill];
    }];
    [RSCInternalErrorReporter setSharedInstance:[[RSCInternalErrorReporter alloc] initWithApiKey:self.configuration.apiKey endpoint:[NSURL URLWithString:self.configuration.endpoints.notify]]];
    [self waitForExpectations:@[expectation] timeout:1];
    
    expectation = [self expectationWithDescription:@"+performBlock: block is called immediately"];
    [RSCInternalErrorReporter performBlock:^(RSCInternalErrorReporter *reporter) {
        XCTAssertNotNil(reporter);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:0];
}

// MARK: - RSCInternalErrorReporterDataSource

- (RSCrashReporterAppWithState *)generateAppWithState:(nonnull NSDictionary *)systemInfo {
    return [RSCrashReporterAppWithState appWithDictionary:@{@"system": systemInfo} config:self.configuration codeBundleId:nil];
}

- (RSCrashReporterDeviceWithState *)generateDeviceWithState:(nonnull NSDictionary *)systemInfo {
    RSCrashReporterDeviceWithState *device = [RSCrashReporterDeviceWithState deviceWithKSCrashReport:@{@"system": systemInfo}];
    device.time = [NSDate date]; // default to current time for handled errors
    return device;
}

@end
