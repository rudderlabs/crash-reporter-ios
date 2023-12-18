//
//  RSCClientObserverTests.m
//  Tests
//
//  Created by Jamie Lynch on 18/03/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCrashReporter.h"
#import "RSCrashReporterClient+Private.h"
#import "RSCrashReporterConfiguration.h"
#import "RSCrashReporterTestConstants.h"
#import "RSCrashReporterMetadata+Private.h"
#import "RSCrashReporterUser+Private.h"

@interface RSCClientObserverTests : XCTestCase
@property RSCrashReporterClient *client;
@property RSCClientObserverEvent event;
@property id value;
@end

@implementation RSCClientObserverTests

- (void)setUp {
    [RSCrashReporter startWithDelegate:nil];
    self.client = RSCrashReporter.client;

    __weak __typeof__(self) weakSelf = self;
    self.client.observer = ^(RSCClientObserverEvent event, id value) {
        weakSelf.event = event;
        weakSelf.value = value;
    };
}

- (void)testUserUpdate {
    [self.client setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];

    XCTAssertEqual(self.event, RSCClientObserverUpdateUser);

    NSDictionary *dict = [self.value toJson];
    XCTAssertEqualObjects(@"123", dict[@"id"]);
    XCTAssertEqualObjects(@"Jamie", dict[@"name"]);
    XCTAssertEqualObjects(@"test@example.com", dict[@"email"]);
}

- (void)testContextUpdate {
    [self.client setContext:@"Foo"];
    XCTAssertEqual(self.event, RSCClientObserverUpdateContext);
    XCTAssertEqualObjects(self.value, @"Foo");
}

- (void)testMetadataUpdate {
    [self.client addMetadata:@"Bar" withKey:@"Foo2" toSection:@"test"];
    XCTAssertEqualObjects(self.value, self.client.metadata);
}

- (void)testRemoveObserver {
    self.event = -1;
    self.value = nil;
    self.client.observer = nil;
    [self.client setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];
    [self.client setContext:@"Foo"];
    [self.client addMetadata:@"Bar" withKey:@"Foo" toSection:@"test"];
    XCTAssertEqual(self.event, -1);
}

- (void)testAddObserverTriggersCallback {
    [self.client setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];
    [self.client setContext:@"Foo"];
    [self.client addMetadata:@"Bar" withKey:@"Foo" toSection:@"test"];
    [self.client addFeatureFlagWithName:@"Testing" variant:@"unit"];

    __block NSDictionary *user;
    __block NSString *context;
    __block RSCrashReporterMetadata *metadata;
    __block RSCrashReporterFeatureFlag *featureFlag;

    RSCClientObserver observer = ^(RSCClientObserverEvent event, id value) {
        switch (event) {
            case RSCClientObserverAddFeatureFlag:
                featureFlag = value;
                break;
            case RSCClientObserverClearFeatureFlag:
                XCTFail(@"RSCClientObserverClearFeatureFlag should not be sent when setting observer");
                break;
            case RSCClientObserverUpdateContext:
                context = value;
                break;
            case RSCClientObserverUpdateMetadata:
                metadata = value;
                break;
            case RSCClientObserverUpdateUser:
                user = [(RSCrashReporterUser *)value toJson];
                break;
        }
    };
    XCTAssertNil(user);
    XCTAssertNil(context);
    XCTAssertNil(metadata);
    self.client.observer = observer;

    NSDictionary *expectedUser = @{@"id": @"123", @"email": @"test@example.com", @"name": @"Jamie"};
    XCTAssertEqualObjects(expectedUser, user);
    XCTAssertEqualObjects(@"Foo", context);
    XCTAssertEqualObjects(self.client.metadata, metadata);
    XCTAssertEqualObjects(featureFlag.name, @"Testing");
    XCTAssertEqualObjects(featureFlag.variant, @"unit");
}

- (void)testFeatureFlags {
    [self.client addFeatureFlags:@[[RSCrashReporterFeatureFlag flagWithName:@"foo" variant:@"bar"]]];
    XCTAssertEqual(self.event, RSCClientObserverAddFeatureFlag);
    XCTAssertEqualObjects([self.value name], @"foo");
    XCTAssertEqualObjects([self.value variant], @"bar");
    
    [self.client addFeatureFlagWithName:@"baz"];
    XCTAssertEqual(self.event, RSCClientObserverAddFeatureFlag);
    XCTAssertEqualObjects([self.value name], @"baz");
    XCTAssertNil([self.value variant]);
    
    [self.client addFeatureFlagWithName:@"baz" variant:@"vvv"];
    XCTAssertEqual(self.event, RSCClientObserverAddFeatureFlag);
    XCTAssertEqualObjects([self.value name], @"baz");
    XCTAssertEqualObjects([self.value variant], @"vvv");
    
    [self.client clearFeatureFlagWithName:@"baz"];
    XCTAssertEqual(self.event, RSCClientObserverClearFeatureFlag);
    XCTAssertEqualObjects(self.value, @"baz");
    
    [self.client clearFeatureFlags];
    XCTAssertEqual(self.event, RSCClientObserverClearFeatureFlag);
    XCTAssertNil(self.value);
}

@end
