//
//  RSCrashReporterDeviceWithState.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>
#import <RSCrashReporter/RSCrashReporterDevice.h>

/**
 * Stateful information set by the notifier about the device on which the event occurred can be
 * found on this class. These values can be accessed and amended if necessary.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterDeviceWithState : RSCrashReporterDevice

/**
 * The number of free bytes of storage available on the device
 */
@property (strong, nullable, nonatomic) NSNumber *freeDisk;

/**
 * The number of free bytes of memory available on the device
 */
@property (strong, nullable, nonatomic) NSNumber *freeMemory;

/**
 * The orientation of the device when the event occurred
 */
@property (copy, nullable, nonatomic) NSString *orientation;

/**
 * The timestamp on the device when the event occurred
 */
@property (strong, nullable, nonatomic) NSDate *time;

@end
