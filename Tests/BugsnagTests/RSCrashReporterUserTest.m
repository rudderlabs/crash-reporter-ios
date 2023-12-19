//
//  RSCrashReporterUserTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterUser+Private.h"

@interface RSCrashReporterUserTest : XCTestCase
@end

@implementation RSCrashReporterUserTest

- (void)testDictDeserialisation {

    NSDictionary *dict = @{
            @"id": @"test",
            @"email": @"fake@example.com",
            @"name": @"Tom Bombadil"
    };
    RSCrashReporterUser *user = [[RSCrashReporterUser alloc] initWithDictionary:dict];

    XCTAssertNotNil(user);
    XCTAssertEqualObjects(user.id, @"test");
    XCTAssertEqualObjects(user.email, @"fake@example.com");
    XCTAssertEqualObjects(user.name, @"Tom Bombadil");
}

- (void)testPayloadSerialisation {
    RSCrashReporterUser *payload = [[RSCrashReporterUser alloc] initWithId:@"test" name:@"Tom Bombadil" emailAddress:@"fake@example.com"];
    NSDictionary *rootNode = [payload toJson];
    XCTAssertNotNil(rootNode);
    XCTAssertEqual(3, [rootNode count]);
    
    XCTAssertEqualObjects(@"test", rootNode[@"id"]);
    XCTAssertEqualObjects(@"fake@example.com", rootNode[@"email"]);
    XCTAssertEqualObjects(@"Tom Bombadil", rootNode[@"name"]);
}

/*- (void)testUserEvent {
    // Setup
    RSCrashReporterEvent *event = [[RSCrashReporterEvent alloc] initWithKSReport:@{
            @"user.metaData": @{
                    @"user": @{
                            @"id": @"123",
                            @"name": @"Jane Smith",
                            @"email": @"jane@example.com",
                    }
            }}];
    XCTAssertEqualObjects(@"123", event.user.id);
    XCTAssertEqualObjects(@"Jane Smith", event.user.name);
    XCTAssertEqualObjects(@"jane@example.com", event.user.email);
}*/

@end
