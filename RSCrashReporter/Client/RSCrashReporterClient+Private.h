//
//  RSCrashReporterClient+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 26/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "RSCDefines.h"
#import "RSCrashReporterInternals.h"

@class RSCAppHangDetector;
@class RSCEventUploader;
@class RSCrashReporterAppWithState;
@class RSCrashReporterBreadcrumbs;
@class RSCrashReporterConfiguration;
@class RSCrashReporterDeviceWithState;
@class RSCrashReporterMetadata;
@class RSCrashReporterNotifier;
@class RSCrashReporterSessionTracker;
@class RSCrashReporterSystemState;

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterClient ()

#pragma mark Properties

@property (nonatomic) BOOL appDidCrashLastLaunch;

@property (nonatomic) RSCAppHangDetector *appHangDetector;

@property (nullable, nonatomic) RSCrashReporterEvent *appHangEvent;

/// The App hang or OOM event that caused the last launch to crash.
@property (nullable, nonatomic) RSCrashReporterEvent *eventFromLastLaunch;

@property (strong, nonatomic) RSCEventUploader *eventUploader;

@property (nonatomic) NSMutableDictionary *extraRuntimeInfo;

@property (atomic) BOOL isStarted;

/// YES if RSCrashReporterClient is ready to handle some internal method calls.
/// It does not mean that it is fully started and ready to receive method calls from outside of the library.
@property (atomic) BOOL readyForInternalCalls;

/// State related metadata
///
/// Upon change this is automatically persisted to disk, making it available when contructing OOM payloads.
/// Is it also added to KSCrashReports under `user.state` by `BSSerializeDataCrashHandler()`.
///
/// Example contents:
///
/// {
///     "app": {
///         "codeBundleId": "com.example.app",
///     },
///     "client": {
///         "context": "MyViewController",
///     },
///     "user": {
///         "id": "abc123",
///         "name": "bob"
///     }
/// }
@property (strong, nonatomic) RSCrashReporterMetadata *state;

@property (strong, nonatomic) NSMutableArray *stateEventBlocks;

@property (strong, nonatomic) RSCrashReporterSystemState *systemState;

#pragma mark Methods

- (void)start;

@end

NS_ASSUME_NONNULL_END
