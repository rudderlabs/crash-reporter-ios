//
//  RSCEventUploader.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 16/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"
#import "RSCrashReporterClient.h"

@class RSCrashReporterApiClient;
@class RSCrashReporterConfiguration;
@class RSCrashReporterEvent;
@class RSCrashReporterNotifier;

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCEventUploader : NSObject

- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)configuration notifier:(RSCrashReporterNotifier *)notifier delegate:(id<RSCrashReporterNotifyDelegate> _Nullable)delegate;

- (void)storeEvent:(RSCrashReporterEvent *)event;

- (void)uploadEvent:(RSCrashReporterEvent *)event completionHandler:(nullable void (^)(void))completionHandler;

- (void)uploadKSCrashReportWithFile:(NSString *)file completionHandler:(nullable void (^)(void))completionHandler;

- (void)uploadStoredEvents;

- (void)uploadStoredEventsAfterDelay:(NSTimeInterval)delay;

- (void)uploadLatestStoredEvent:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
