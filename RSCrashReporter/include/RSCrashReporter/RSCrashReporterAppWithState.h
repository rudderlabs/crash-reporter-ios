//
//  RSCrashReporterAppWithState.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterApp.h>
#import <RSCrashReporter/RSCrashReporterDefines.h>

/**
 * Stateful information set by the notifier about your app can be found on this class. These values
 * can be accessed and amended if necessary.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterAppWithState : RSCrashReporterApp

/**
 * The number of milliseconds the application was running before the event occurred
 */
@property (strong, nullable, nonatomic) NSNumber *duration;

/**
 * The number of milliseconds the application was running in the foreground before the
 * event occurred
 */
@property (strong, nullable, nonatomic) NSNumber *durationInForeground;

/**
 * Whether the application was in the foreground when the event occurred
 */
@property (nonatomic) BOOL inForeground;

/**
 * Whether the app was still launching when the event occurred.
 */
@property (nonatomic) BOOL isLaunching;

@end
