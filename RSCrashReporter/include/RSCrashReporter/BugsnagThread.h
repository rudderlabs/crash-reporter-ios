//
//  RSCrashReporterThread.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>

typedef NS_OPTIONS(NSUInteger, RSCThreadType) {
    RSCThreadTypeCocoa NS_SWIFT_NAME(cocoa) = 0,
    RSCThreadTypeReactNativeJs = 1 << 1
};

@class RSCrashReporterStackframe;

/**
 * A representation of thread information recorded as part of a RSCrashReporterEvent.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterThread : NSObject

/**
 * A unique ID which identifies this thread
 */
@property (copy, nullable, nonatomic) NSString *id;

/**
 * The name which identifies this thread
 */
@property (copy, nullable, nonatomic) NSString *name;

/**
 * Whether the error being reported happened in this thread
 */
@property (readonly, nonatomic) BOOL errorReportingThread;

/**
 * The current state of this thread
 */
@property (copy, nullable, nonatomic) NSString *state;

/**
 * Sets a representation of this thread's stacktrace
 */
@property (copy, nonnull, nonatomic) NSArray<RSCrashReporterStackframe *> *stacktrace;

/**
 * Determines the type of thread based on the originating platform
 * (intended for internal use only)
 */
@property (nonatomic) RSCThreadType type;

@end
