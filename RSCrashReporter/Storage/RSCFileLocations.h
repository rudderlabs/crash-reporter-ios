//
//  RSCFileLocations.h
//  RSCrashReporter
//
//  Created by Karl Stenerud on 05.01.21.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCFileLocations : NSObject

@property (readonly, nonatomic) NSString *breadcrumbs;
@property (readonly, nonatomic) NSString *events;
@property (readonly, nonatomic) NSString *kscrashReports;
@property (readonly, nonatomic) NSString *sessions;

/**
 * File containing details of the current app hang (if the app is hung)
 */
@property (readonly, nonatomic) NSString *appHangEvent;

/**
 * File whose presence indicates that the libary at least attempted to handle the last
 * crash (in case it crashed before writing enough information).
 */
@property (readonly, nonatomic) NSString *flagHandledCrash;

/**
 * RSCrashReporter client configuration
 */
@property (readonly, nonatomic) NSString *configuration;

/**
 * General per-launch metadata
 */
@property (readonly, nonatomic) NSString *metadata;

/**
 * RSCRunContext
 */
@property (readonly, nonatomic) NSString *runContext;

/**
 * State info that gets added to the low level crash report.
 */
@property (readonly, nonatomic) NSString *state;

/**
 * State information about the app and operating envronment.
 */
@property (readonly, nonatomic) NSString *systemState;

+ (instancetype) current;
+ (instancetype) v1;

@end

NS_ASSUME_NONNULL_END
