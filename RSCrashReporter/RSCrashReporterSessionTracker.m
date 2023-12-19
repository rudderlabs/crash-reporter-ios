//
//  RSCrashReporterSessionTracker.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "RSCrashReporterSessionTracker.h"

#import "RSCAppKit.h"
#import "RSCDefines.h"
#import "RSCUIKit.h"
#import "RSCWatchKit.h"
#import "RSC_KSSystemInfo.h"
#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterClient+Private.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterDevice+Private.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterSession+Private.h"
#import "RSCrashReporterUser+Private.h"

/**
 Number of seconds in background required to make a new session
 */
static NSTimeInterval const RSCNewSessionBackgroundDuration = 30;

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterSessionTracker ()
@property (strong, nonatomic) RSCrashReporterConfiguration *config;
@property (weak, nonatomic) RSCrashReporterClient *client;
@property (strong, nonatomic) NSDate *backgroundStartTime;
@property (nonatomic) NSMutableDictionary *extraRuntimeInfo;
@end

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterSessionTracker

- (instancetype)initWithConfig:(RSCrashReporterConfiguration *)config client:(RSCrashReporterClient *)client {
    if ((self = [super init])) {
        _config = config;
        _client = client;
        _sessionUploader = [[RSCSessionUploader alloc] initWithConfig:config notifier:client.notifier];
        _extraRuntimeInfo = [NSMutableDictionary new];
    }
    return self;
}

- (void)startWithNotificationCenter:(NSNotificationCenter *)notificationCenter isInForeground:(BOOL)isInForeground {
#if !TARGET_OS_WATCH
    if ([RSC_KSSystemInfo isRunningInAppExtension]) {
        // UIApplication lifecycle notifications and UIApplicationState, which the automatic session tracking logic
        // depends on, are not available in app extensions.
        if (self.config.autoTrackSessions) {
            rsc_log_info(@"Automatic session tracking is not supported in app extensions");
        }
        return;
    }
#endif
    
    if (isInForeground) {
        [self startNewSessionIfAutoCaptureEnabled];
    } else {
        rsc_log_debug(@"Not starting session because app is not in the foreground");
    }

#if TARGET_OS_OSX
    [notificationCenter addObserver:self
               selector:@selector(handleAppForegroundEvent)
                   name:NSApplicationWillBecomeActiveNotification
                 object:nil];

    [notificationCenter addObserver:self
               selector:@selector(handleAppForegroundEvent)
                   name:NSApplicationDidBecomeActiveNotification
                 object:nil];

    [notificationCenter addObserver:self
               selector:@selector(handleAppBackgroundEvent)
                   name:NSApplicationDidResignActiveNotification
                 object:nil];
#elif TARGET_OS_WATCH
    [notificationCenter addObserver:self
               selector:@selector(handleAppForegroundEvent)
                   name:WKApplicationWillEnterForegroundNotification
                 object:nil];

    [notificationCenter addObserver:self
               selector:@selector(handleAppForegroundEvent)
                   name:WKApplicationDidBecomeActiveNotification
                 object:nil];

    [notificationCenter addObserver:self
               selector:@selector(handleAppBackgroundEvent)
                   name:WKApplicationDidEnterBackgroundNotification
                 object:nil];
#else
    [notificationCenter addObserver:self
               selector:@selector(handleAppForegroundEvent)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];

    [notificationCenter addObserver:self
               selector:@selector(handleAppForegroundEvent)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];

    [notificationCenter addObserver:self
               selector:@selector(handleAppBackgroundEvent)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
#endif
}

#pragma mark - Creating and sending a new session

- (void)pauseSession {
    self.currentSession.stopped = YES;

    RSCSessionUpdateRunContext(nil);
}

- (BOOL)resumeSession {
    RSCrashReporterSession *session = self.currentSession;

    if (session == nil) {
        [self startNewSession];
        return NO;
    } else {
        BOOL stopped = session.isStopped;
        session.stopped = NO;
        RSCSessionUpdateRunContext(session);
        return stopped;
    }
}

- (RSCrashReporterSession *)runningSession {
    RSCrashReporterSession *session = self.currentSession;

    if (session == nil || session.isStopped) {
        return nil;
    }
    return session;
}

- (void)startNewSessionIfAutoCaptureEnabled {
    if (self.config.autoTrackSessions) {
        [self startNewSession];
    }
}

- (void)startNewSession {
    NSSet<NSString *> *releaseStages = self.config.enabledReleaseStages;
    if (releaseStages != nil && ![releaseStages containsObject:self.config.releaseStage ?: @""]) {
        return;
    }
    if (self.config.sessionURL == nil) {
        rsc_log_err(@"The session tracking endpoint has not been set. Session tracking is disabled");
        return;
    }

    NSDictionary *systemInfo = [RSC_KSSystemInfo systemInfo];
    RSCrashReporterApp *app = [RSCrashReporterApp appWithDictionary:@{@"system": systemInfo}
                                             config:self.config
                                       codeBundleId:self.codeBundleId];
    RSCrashReporterDevice *device = [RSCrashReporterDevice deviceWithKSCrashReport:@{@"system": systemInfo}];
    [device appendRuntimeInfo:self.extraRuntimeInfo];

    RSCrashReporterSession *newSession = [[RSCrashReporterSession alloc] initWithId:[[NSUUID UUID] UUIDString]
                                                          startedAt:[NSDate date]
                                                               user:[self.client.user withId]
                                                                app:app
                                                             device:device];

    for (RSCrashReporterOnSessionBlock onSessionBlock in self.config.onSessionBlocks) {
        @try {
            if (!onSessionBlock(newSession)) {
                return;
            }
        } @catch (NSException *exception) {
            rsc_log_err(@"Error from onSession callback: %@", exception);
        }
    }

    self.currentSession = newSession;

    RSCSessionUpdateRunContext(newSession);

    [self.sessionUploader uploadSession:newSession];
}

- (void)addRuntimeVersionInfo:(NSString *)info
                      withKey:(NSString *)key {
    if (info != nil && key != nil) {
        self.extraRuntimeInfo[key] = info;
    }
}

#pragma mark - Handling events

- (void)handleAppBackgroundEvent {
    self.backgroundStartTime = [NSDate date];
}

- (void)handleAppForegroundEvent {
    if (!self.currentSession ||
        (self.backgroundStartTime && [[NSDate date] timeIntervalSinceDate:self.backgroundStartTime] >= RSCNewSessionBackgroundDuration)) {
        [self startNewSessionIfAutoCaptureEnabled];
    }
    self.backgroundStartTime = nil;
}

- (void)incrementEventCountUnhandled:(BOOL)unhandled {
    RSCrashReporterSession *session = [self runningSession];

    if (session == nil) {
        return;
    }

    @synchronized (session) {
        if (unhandled) {
            session.unhandledCount++;
        } else {
            session.handledCount++;
        }
        RSCSessionUpdateRunContext(session);
    }
}

@end
