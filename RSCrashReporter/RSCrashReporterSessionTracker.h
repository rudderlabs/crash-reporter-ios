//
//  RSCrashReporterSessionTracker.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterConfiguration.h>
#import <RSCrashReporter/RSCrashReporterSession.h>

#import "RSCSessionUploader.h"

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterSessionTracker : NSObject

/**
 Create a new session tracker

 @param config The RSCrashReporter configuration to use
 @return A new session tracker
 */
- (instancetype)initWithConfig:(RSCrashReporterConfiguration *)config client:(nullable RSCrashReporterClient *)client;

- (void)startWithNotificationCenter:(NSNotificationCenter *)notificationCenter isInForeground:(BOOL)isInForeground;

/**
 Record and send a new session
 */
- (void)startNewSession;

- (void)pauseSession;
- (BOOL)resumeSession;

/**
 Record a new auto-captured session if neededed. Auto-captured sessions are only
 recorded and sent if -[RSCrashReporterConfiguration autoTrackSessions] is YES
 */
- (void)startNewSessionIfAutoCaptureEnabled;

/**
 Handle some variation of RSCrashReporter.notify() being called.
 Increments the number of handled or unhandled errors recorded for the current session, if
 a session exists.
 */
- (void)incrementEventCountUnhandled:(BOOL)unhandled;

@property (copy, nonatomic) NSString *codeBundleId;

@property (nullable, nonatomic) RSCrashReporterSession *currentSession;

/**
 * Retrieves the running session, or nil if the session is stopped or has not yet been started/resumed.
 */
@property (nullable, readonly, nonatomic) RSCrashReporterSession *runningSession;

@property (strong, nonatomic) RSCSessionUploader *sessionUploader;

- (void)addRuntimeVersionInfo:(NSString *)info
                      withKey:(NSString *)key;

@end

@interface RSCrashReporterSessionTracker (/* not objc_direct */)

/**
 Handle the app foregrounding event. If more than 30s has elapsed since being
 sent to the background, records a new session if session auto-capture is
 enabled.
 Must be called from the main thread.
 */
- (void)handleAppForegroundEvent;

/**
 Handle the app backgrounding event. Tracks time between foreground and
 background to determine when to automatically record a session.
 Must be called from the main thread.
 */
- (void)handleAppBackgroundEvent;

@end

NS_ASSUME_NONNULL_END
