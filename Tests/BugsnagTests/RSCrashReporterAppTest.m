//
//  RSCrashReporterDeviceTest.m
//  Tests
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSC_KSSystemInfo.h"
#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterAppWithState+Private.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterTestConstants.h"

#include <sys/sysctl.h>

@interface RSCrashReporterAppTest : XCTestCase
@property NSDictionary *data;
@property RSCrashReporterConfiguration *config;
@property NSString *codeBundleId;
@end

@implementation RSCrashReporterAppTest

- (void)setUp {
    [super setUp];
    // this mocks the structure of a KSCrashReport which is persisted to disk
    // and used to populate the contents of RSCrashReporterApp/RSCrashReporterAppWithState
    self.data = @{
            @"system": @{
                    @"application_stats": @{
                            @"active_time_since_launch": @2,
                            @"background_time_since_launch": @5,
                            @"application_in_foreground": @YES,
                    },
                    @"binary_arch": @"arm64",
                    @"CFBundleExecutable": @"MyIosApp",
                    @"CFBundleIdentifier": @"com.example.foo.MyIosApp",
                    @"CFBundleShortVersionString": @"5.6.3",
                    @"CFBundleVersion": @"1",
                    @"app_uuid": @"dsym-uuid-123"
            },
            @"user": @{
                    @"config": @{
                            @"releaseStage": @"beta"
                    }
            }
    };

    self.config = [[RSCrashReporterConfiguration alloc] initWithDictionaryRepresentation:self.data[@"user"][@"config"]];
    self.config.appType = @"iOS";
    self.config.bundleVersion = nil;
    self.config.appVersion = @"3.14.159";
    self.codeBundleId = @"bundle-123";
}

- (void)testApp {
    RSCrashReporterApp *app = [RSCrashReporterApp appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];

    // verify stateless fields
    XCTAssertEqualObjects(app.binaryArch, @"arm64");
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertEqualObjects(@"dsym-uuid-123", app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"3.14.159", app.version);
}

- (void)testAppWithState {
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];

    // verify stateful fields
    XCTAssertEqualObjects(@7000, app.duration);
    XCTAssertEqualObjects(@2000, app.durationInForeground);
    XCTAssertTrue(app.inForeground);

    // verify stateless fields
    XCTAssertEqualObjects(app.binaryArch, @"arm64");
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertEqualObjects(@"dsym-uuid-123", app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"3.14.159", app.version);
}

- (void)testAppToDict {
    self.config.appVersion = nil; // Check that the system value is picked up
    RSCrashReporterApp *app = [RSCrashReporterApp appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    NSDictionary *dict = [app toDict];

    // verify stateless fields
    XCTAssertEqualObjects(dict[@"binaryArch"], @"arm64");
    XCTAssertEqualObjects(@"1", dict[@"bundleVersion"]);
    XCTAssertEqualObjects(@"bundle-123", dict[@"codeBundleId"]);
    XCTAssertEqualObjects(@[@"dsym-uuid-123"], dict[@"dsymUUIDs"]);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", dict[@"id"]);
    XCTAssertEqualObjects(@"beta", dict[@"releaseStage"]);
    XCTAssertEqualObjects(@"iOS", dict[@"type"]);
    XCTAssertEqualObjects(@"5.6.3", dict[@"version"]);
}

- (void)testAppWithStateToDict {
    self.config.appVersion = nil; // Check that the system value is picked up
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    NSDictionary *dict = [app toDict];

    // verify stateful fields
    XCTAssertEqualObjects(@7000, dict[@"duration"]);
    XCTAssertEqualObjects(@2000, dict[@"durationInForeground"]);
    XCTAssertTrue([dict[@"inForeground"] boolValue]);

    // verify stateless fields
    XCTAssertEqualObjects(dict[@"binaryArch"], @"arm64");
    XCTAssertEqualObjects(@"1", dict[@"bundleVersion"]);
    XCTAssertEqualObjects(@"bundle-123", dict[@"codeBundleId"]);
    XCTAssertEqualObjects(@[@"dsym-uuid-123"], dict[@"dsymUUIDs"]);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", dict[@"id"]);
    XCTAssertEqualObjects(@"beta", dict[@"releaseStage"]);
    XCTAssertEqualObjects(@"iOS", dict[@"type"]);
    XCTAssertEqualObjects(@"5.6.3", dict[@"version"]);
}

- (void)testAppFromJson {
    NSDictionary *json = @{
            @"binaryArch": @"x86_64",
            @"duration": @7000,
            @"durationInForeground": @2000,
            @"inForeground": @YES,
            @"bundleVersion": @"1",
            @"codeBundleId": @"bundle-123",
            @"dsymUUIDs": @[@"dsym-uuid-123"],
            @"id": @"com.example.foo.MyIosApp",
            @"releaseStage": @"beta",
            @"type": @"iOS",
            @"version": @"5.6.3",
    };
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appFromJson:json];
    XCTAssertNotNil(app);

    // verify stateful fields
    XCTAssertEqualObjects(@7000, app.duration);
    XCTAssertEqualObjects(@2000, app.durationInForeground);
    XCTAssertTrue(app.inForeground);

    // verify stateless fields
    XCTAssertEqualObjects(app.binaryArch, @"x86_64");
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertEqualObjects(@"dsym-uuid-123", app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"5.6.3", app.version);
}

- (void)testAppVersionPrecedence {
    // default to system.CFBundleShortVersionString
    self.config.appVersion = nil;
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    XCTAssertEqualObjects(@"5.6.3", app.version);

    // 2nd precedence is config.appVersion
    self.config.appVersion = @"4.2.6";
    app = [RSCrashReporterAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    XCTAssertEqualObjects(@"4.2.6", app.version);
}

- (void)testBundleVersionPrecedence {
    // default to system.CFBundleVersion
    self.config.bundleVersion = nil;
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    XCTAssertEqualObjects(@"1", app.bundleVersion);

    // 2nd precedence is config.bundleVersion
    self.config.bundleVersion = @"4.2.6";
    app = [RSCrashReporterAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    XCTAssertEqualObjects(@"4.2.6", app.bundleVersion);
}

- (void)testRSCParseAppMetadata {
    NSDictionary *metadata = RSCParseAppMetadata(@{@"system": [RSC_KSSystemInfo systemInfo]});
    int proc_translated = 0;
    size_t size = sizeof(proc_translated);
    if (!sysctlbyname("sysctl.proc_translated", &proc_translated, &size, NULL, 0) && proc_translated) {
        XCTAssertEqualObjects(metadata[@"runningOnRosetta"], @YES);
    }
}

@end
