//
//  RSCrashReporterSystemInfo.h
//  RSCrashReporter
//
//  Created by Karl Stenerud on 21.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterConfiguration.h>

#import "RSCDefines.h"
#import "RSCKeys.h"

#define SYSTEMSTATE_KEY_APP @"app"
#define SYSTEMSTATE_KEY_DEVICE @"device"

#define PLATFORM_WORD_SIZE sizeof(void*)*8

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterSystemState : NSObject

@property(readonly,nonatomic) NSDictionary *lastLaunchState;
@property(readonly,atomic) NSDictionary *currentLaunchState;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)config;

- (void)setCodeBundleID:(NSString*)codeBundleID;

@property (nonatomic) NSUInteger consecutiveLaunchCrashes;

/**
 * Purge all stored system state.
 */
- (void)purge;

@end

NS_ASSUME_NONNULL_END
