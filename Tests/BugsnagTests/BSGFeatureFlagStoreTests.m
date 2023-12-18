//
//  RSCFeatureFlagStoreTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCFeatureFlagStore.h"

#import <XCTest/XCTest.h>

@interface RSCFeatureFlagStoreTests : XCTestCase

@end

@implementation RSCFeatureFlagStoreTests

- (void)test {
    RSCFeatureFlagStore *store = [[RSCFeatureFlagStore alloc] init];
    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store), @[]);

    RSCFeatureFlagStoreAddFeatureFlag(store, @"featureC", @"checked");
    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"featureC", @"variant": @"checked"}]));
    
    RSCFeatureFlagStoreAddFeatureFlag(store, @"featureA", @"enabled");
    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA", @"variant": @"enabled"}
                          ]));

    RSCFeatureFlagStoreAddFeatureFlag(store, @"featureB", nil);
    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA", @"variant": @"enabled"},
                            @{@"featureFlag": @"featureB"}
                          ]));


    RSCFeatureFlagStoreAddFeatureFlags(store, @[[RSCrashReporterFeatureFlag flagWithName:@"featureA"]]);
    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA"},
                            @{@"featureFlag": @"featureB"},
                          ]));

    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(RSCFeatureFlagStoreFromJSON(RSCFeatureFlagStoreToJSON(store))),
                          RSCFeatureFlagStoreToJSON(store));
    
    RSCFeatureFlagStoreClear(store, @"featureB");
    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA"}
                          ]));

    RSCFeatureFlagStoreClear(store, nil);
    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store), @[]);
}

- (void)testAddRemoveMany {
    // Tests that rebuildIfTooManyHoles works as expected

    RSCFeatureFlagStore *store = [[RSCFeatureFlagStore alloc] init];

    RSCFeatureFlagStoreAddFeatureFlag(store, @"blah", @"testing");
    for (int j = 0; j < 10; j++) {
        for (int i = 0; i < 1000; i++) {
            NSString *name = [NSString stringWithFormat:@"%d-%d", j, i];
            RSCFeatureFlagStoreAddFeatureFlag(store, name, nil);
            if (i < 999) {
                RSCFeatureFlagStoreClear(store, name);
            }
        }
    }

    XCTAssertEqualObjects(RSCFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"blah", @"variant": @"testing"},
                            @{@"featureFlag": @"0-999"},
                            @{@"featureFlag": @"1-999"},
                            @{@"featureFlag": @"2-999"},
                            @{@"featureFlag": @"3-999"},
                            @{@"featureFlag": @"4-999"},
                            @{@"featureFlag": @"5-999"},
                            @{@"featureFlag": @"6-999"},
                            @{@"featureFlag": @"7-999"},
                            @{@"featureFlag": @"8-999"},
                            @{@"featureFlag": @"9-999"},
                          ]));
}

- (void)testAddFeatureFlagPerformance {
    RSCFeatureFlagStore *store = [[RSCFeatureFlagStore alloc] init];

    __auto_type block = ^{
        for (int i = 0; i < 1000; i++) {
            NSString *name = [NSString stringWithFormat:@"%d", i];
            RSCFeatureFlagStoreAddFeatureFlag(store, name, nil);
        }
    };

    block();

    [self measureBlock:block];
}

- (void)testDictionaryPerformance {
    // For comparision to show the best performance possible

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    __auto_type block = ^{
        for (int i = 0; i < 1000; i++) {
            NSString *name = [NSString stringWithFormat:@"%d", i];
            [dictionary setObject:[NSNull null] forKey:name];
        }
    };

    block();

    [self measureBlock:block];
}

@end
