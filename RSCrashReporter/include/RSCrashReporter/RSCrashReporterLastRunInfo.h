//
//  RSCrashReporterLastRunInfo.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 10/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Contains information about the last run of the app.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterLastRunInfo : NSObject

/**
 * The number of consecutive runs that have ended with a crash while launching.
 *
 * See `RSCrashReporterConfiguration.launchDurationMillis` for more information.
 */
@property (readonly, nonatomic) NSUInteger consecutiveLaunchCrashes;

/**
 * True if the previous run crashed.
 */
@property (readonly, nonatomic) BOOL crashed;

/**
 * True if the previous run crashed while launching.
 *
 * See `RSCrashReporterConfiguration.launchDurationMillis` for more information.
 */
@property (readonly, nonatomic) BOOL crashedDuringLaunch;

@end

NS_ASSUME_NONNULL_END
