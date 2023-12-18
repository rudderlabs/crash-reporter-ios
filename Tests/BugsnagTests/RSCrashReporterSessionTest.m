//
//  RSCrashReporterSessionTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 RSCrashReporter. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterDevice+Private.h"
#import "RSCrashReporterSession+Private.h"
#import "RSCrashReporterUser+Private.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporterTestConstants.h"

@interface RSCrashReporterSessionTest : XCTestCase
@property RSCrashReporterApp *app;
@property RSCrashReporterDevice *device;
@property NSDictionary *serializedSession;
@end

@implementation RSCrashReporterSessionTest

- (void)setUp {
    self.app = [self generateApp];
    self.device = [self generateDevice];
    self.serializedSession = [self generateSerializedSession];
}

- (RSCrashReporterApp *)generateApp {
    NSDictionary *appData = @{
            @"system": @{
                    @"application_stats": @{
                            @"active_time_since_launch": @2,
                            @"background_time_since_launch": @5,
                            @"application_in_foreground": @YES,
                    },
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

    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithDictionaryRepresentation:appData[@"user"][@"config"]];
    config.appType = @"iOS";
    config.bundleVersion = nil;
    return [RSCrashReporterApp appWithDictionary:appData config:config codeBundleId:@"bundle-123"];
}

- (RSCrashReporterDevice *)generateDevice {
    NSDictionary *deviceData = @{
            @"system": @{
                    @"model": @"iPhone 6",
                    @"machine": @"x86_64",
                    @"system_name": @"iPhone OS",
                    @"system_version": @"8.1",
                    @"os_version": @"14B25",
                    @"clang_version": @"10.0.0 (clang-1000.11.45.5)",
                    @"jailbroken": @YES,
                    @"memory": @{
                            @"size": @15065522176,
                            @"free": @742920192
                    },
                    @"device_app_hash": @"123"
            },
            @"report": @{
                    @"timestamp": @"2014-12-02T01:56:13Z"
            },
            @"user": @{
                    @"state": @{
                            @"deviceState": @{
                                    @"orientation": @"portrait"
                            }
                    }
            }
    };
    RSCrashReporterDevice *device = [RSCrashReporterDevice deviceWithKSCrashReport:deviceData];
    device.locale = @"en-US";
    return device;
}

- (NSDictionary *)generateSerializedSession {
    NSDictionary *dict = @{
            @"id": @"test",
            @"startedAt": [RSC_RFC3339DateTool stringFromDate:[NSDate dateWithTimeIntervalSince1970:0]],
            @"unhandledCount": @1,
            @"handledCount": @2,
            @"user": @{
                    @"id": @"123",
                    @"name": @"Joe Bloggs",
                    @"email": @"joe@example.com"
            },
            @"app": [self.app toDict],
            @"device": [self.device toDictionary],
    };
    return dict;
}

- (void)testPayloadSerialization {
    NSDate *now = [NSDate date];
    RSCrashReporterUser *user = [[RSCrashReporterUser alloc] initWithId:@"123" name:@"Joe Bloggs" emailAddress:@"joe@example.com"];
    RSCrashReporterSession *payload = [[RSCrashReporterSession alloc] initWithId:@"test"
                                                       startedAt:now
                                                            user:user
                                                             app:self.app
                                                          device:self.device];
    payload.unhandledCount = 1;
    payload.handledCount = 2;

    NSDictionary *rootNode = RSCSessionToDictionary(payload);
    XCTAssertNotNil(rootNode);
    XCTAssertEqualObjects(@"test", rootNode[@"id"]);
    XCTAssertEqualObjects([RSC_RFC3339DateTool stringFromDate:now], rootNode[@"startedAt"]);

    // user
    XCTAssertEqualObjects(@"123", rootNode[@"user"][@"id"]);
    XCTAssertEqualObjects(@"Joe Bloggs", rootNode[@"user"][@"name"]);
    XCTAssertEqualObjects(@"joe@example.com", rootNode[@"user"][@"email"]);

    // app
    NSDictionary *app = rootNode[@"app"];
    XCTAssertNotNil(app);
    XCTAssertEqualObjects(@"1", app[@"bundleVersion"]);
    XCTAssertEqualObjects(@"bundle-123", app[@"codeBundleId"]);
    XCTAssertEqualObjects(@[@"dsym-uuid-123"], app[@"dsymUUIDs"]);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app[@"id"]);
    XCTAssertEqualObjects(@"beta", app[@"releaseStage"]);
    XCTAssertEqualObjects(@"iOS", app[@"type"]);
    XCTAssertEqualObjects(@"5.6.3", app[@"version"]);

    // device
    NSDictionary *device = rootNode[@"device"];
    XCTAssertNotNil(device);
    XCTAssertTrue(device[@"jailbroken"]);
//    XCTAssertEqualObjects(@"123", device[@"id"]);
    XCTAssertEqualObjects(@"en-US", device[@"locale"]);
    XCTAssertEqualObjects(@"Apple", device[@"manufacturer"]);
    XCTAssertEqualObjects(@"x86_64", device[@"model"]);
    XCTAssertEqualObjects(@"iPhone 6", device[@"modelNumber"]);
    XCTAssertEqualObjects(@"iPhone OS", device[@"osName"]);
    XCTAssertEqualObjects(@"8.1", device[@"osVersion"]);
    XCTAssertEqualObjects(@15065522176, device[@"totalMemory"]);

    NSDictionary *runtimeVersions = @{
            @"osBuild": @"14B25",
            @"clangVersion": @"10.0.0 (clang-1000.11.45.5)"
    };
    XCTAssertEqualObjects(runtimeVersions, device[@"runtimeVersions"]);
}

- (void)testPayloadDeserialization {
    RSCrashReporterSession *session = RSCSessionFromDictionary(self.serializedSession);
    XCTAssertNotNil(session);

    XCTAssertEqualObjects(@"test", session.id);
    XCTAssertNotNil(session.startedAt);
    XCTAssertEqual(2, session.handledCount);
    XCTAssertEqual(1, session.unhandledCount);

    // user
    XCTAssertNotNil(session.user);
    XCTAssertEqualObjects(@"123", session.user.id);
    XCTAssertEqualObjects(@"Joe Bloggs", session.user.name);
    XCTAssertEqualObjects(@"joe@example.com", session.user.email);

    // app
    RSCrashReporterApp *app = session.app;
    XCTAssertNotNil(app);
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertEqualObjects(@"dsym-uuid-123", app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"5.6.3", app.version);

    // device
    RSCrashReporterDevice *device = session.device;
    XCTAssertNotNil(device);
    XCTAssertTrue(device.jailbroken);
//    XCTAssertEqualObjects(@"123", device.id);
    XCTAssertEqualObjects(@"en-US", device.locale);
    XCTAssertEqualObjects(@"Apple", device.manufacturer);
    XCTAssertEqualObjects(@"x86_64", device.model);
    XCTAssertEqualObjects(@"iPhone 6", device.modelNumber);
    XCTAssertEqualObjects(@"iPhone OS", device.osName);
    XCTAssertEqualObjects(@"8.1", device.osVersion);
    XCTAssertEqualObjects(@15065522176, device.totalMemory);

    NSDictionary *runtimeVersions = @{
            @"osBuild": @"14B25",
            @"clangVersion": @"10.0.0 (clang-1000.11.45.5)"
    };
    XCTAssertEqualObjects(runtimeVersions, device.runtimeVersions);
}

- (void)testDeserializingEmptyPayload {
    NSDictionary *dict = @{
            @"id": @"test",
            @"startedAt": [RSC_RFC3339DateTool stringFromDate:[NSDate dateWithTimeIntervalSince1970:0]],
            @"unhandledCount": @1,
            @"handledCount": @2
    };
    RSCrashReporterSession *session = RSCSessionFromDictionary(dict);
    XCTAssertNotNil(session);
    XCTAssertEqualObjects(@"test", session.id);
    XCTAssertNotNil(session.startedAt);
    XCTAssertEqual(2, session.handledCount);
    XCTAssertEqual(1, session.unhandledCount);
    XCTAssertNotNil(session.app);
    XCTAssertNotNil(session.device);
}

@end
