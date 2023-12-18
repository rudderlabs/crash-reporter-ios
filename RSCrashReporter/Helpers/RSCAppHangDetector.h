//
//  RSCAppHangDetector.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 01/03/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCDefines.h"

#if RSC_HAVE_APP_HANG_DETECTION

#import <Foundation/Foundation.h>

@class RSCrashReporterConfiguration;
@class RSCrashReporterEvent;
@class RSCrashReporterThread;

NS_ASSUME_NONNULL_BEGIN

@protocol RSCAppHangDetectorDelegate;


RSC_OBJC_DIRECT_MEMBERS
@interface RSCAppHangDetector : NSObject

- (void)startWithDelegate:(id<RSCAppHangDetectorDelegate>)delegate;

- (void)stop;

@end


@protocol RSCAppHangDetectorDelegate <NSObject>

@property (readonly) RSCrashReporterConfiguration *configuration;

- (void)appHangDetectedAtDate:(NSDate *)date withThreads:(NSArray<RSCrashReporterThread *> *)threads systemInfo:(NSDictionary *)systemInfo;

- (void)appHangEnded;

@end

NS_ASSUME_NONNULL_END

#endif
