//
//  RSCrashReporterClient.m
//
//  Created by Conrad Irwin on 2014-10-01.
//
//  Copyright (c) 2014 RSCrashReporter, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RSCrashReporterClient+Private.h"

#import "RSCAppHangDetector.h"
#import "RSCAppKit.h"
#import "RSCConnectivity.h"
#import "RSCCrashSentry.h"
#import "RSCDefines.h"
#import "RSCEventUploader.h"
#import "RSCFileLocations.h"
#import "RSCHardware.h"
#import "RSCInternalErrorReporter.h"
#import "RSCJSONSerialization.h"
#import "RSCKeys.h"
#import "RSCNetworkBreadcrumb.h"
#import "RSCNotificationBreadcrumbs.h"
#import "RSCRunContext.h"
#import "RSCSerialization.h"
#import "RSCTelemetry.h"
#import "RSCUIKit.h"
#import "RSCUtils.h"
#import "RSC_KSCrashC.h"
#import "RSC_KSSystemInfo.h"
#import "RSCrashReporter.h"
#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterAppWithState+Private.h"
#import "RSCrashReporterBreadcrumb+Private.h"
#import "RSCrashReporterBreadcrumbs.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterDeviceWithState+Private.h"
#import "RSCrashReporterError+Private.h"
#import "RSCrashReporterErrorTypes.h"
#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterFeatureFlag.h"
#import "RSCrashReporterHandledState.h"
#import "RSCrashReporterLastRunInfo+Private.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterMetadata+Private.h"
#import "RSCrashReporterNotifier.h"
#import "RSCrashReporterPlugin.h"
#import "RSCrashReporterSession+Private.h"
#import "RSCrashReporterSessionTracker.h"
#import "RSCrashReporterStackframe+Private.h"
#import "RSCrashReporterSystemState.h"
#import "RSCrashReporterThread+Private.h"
#import "RSCrashReporterUser+Private.h"

static struct {
    // Contains the user-specified metadata, including the user tab from config.
    char *metadataJSON;
    // Contains the RSCrashReporter configuration, all under the "config" tab.
    char *configJSON;
    // Contains notifier state under "deviceState", and crash-specific
    // information under "crash".
    char *stateJSON;
    // Usage telemetry, from RSCTelemetryCreateUsage()
    char *usageJSON;
    // User onCrash handler
    void (*onCrash)(const RSC_KSCrashReportWriter *writer);
} rsc_g_bugsnag_data;

static char *crashSentinelPath;

/**
 *  Handler executed when the application crashes. Writes information about the
 *  current application state using the crash report writer.
 *
 *  @param writer report writer which will receive updated metadata
 */
static void BSSerializeDataCrashHandler(const RSC_KSCrashReportWriter *writer) {
    BOOL isCrash = YES;
    RSCSessionWriteCrashReport(writer);

    if (isCrash) {
        writer->addJSONElement(writer, "config", rsc_g_bugsnag_data.configJSON);
        writer->addJSONElement(writer, "metaData", rsc_g_bugsnag_data.metadataJSON);
        writer->addJSONElement(writer, "state", rsc_g_bugsnag_data.stateJSON);

        writer->beginObject(writer, "app"); {
            if (rsc_runContext->memoryLimit) {
                writer->addUIntegerElement(writer, "freeMemory", rsc_runContext->memoryAvailable);
                writer->addUIntegerElement(writer, "memoryLimit", rsc_runContext->memoryLimit);
            }
            if (rsc_runContext->memoryFootprint) {
                writer->addUIntegerElement(writer, "memoryUsage", rsc_runContext->memoryFootprint);
            }
        }
        writer->endContainer(writer);

#if RSC_HAVE_BATTERY
        if (RSCIsBatteryStateKnown(rsc_runContext->batteryState)) {
            writer->addFloatingPointElement(writer, "batteryLevel", rsc_runContext->batteryLevel);
            writer->addBooleanElement(writer, "charging", RSCIsBatteryCharging(rsc_runContext->batteryState));
        }
#endif
#if TARGET_OS_IOS
        writer->addIntegerElement(writer, "orientation", rsc_runContext->lastKnownOrientation);
#endif
        writer->addBooleanElement(writer, "isLaunching", rsc_runContext->isLaunching);
        writer->addIntegerElement(writer, "thermalState", rsc_runContext->thermalState);

        RSCrashReporterBreadcrumbsWriteCrashReport(writer);

        // Create a file to indicate that the crash has been handled by
        // the library. This exists in case the subsequent `onCrash` handler
        // crashes or otherwise corrupts the crash report file.
        int fd = open(crashSentinelPath, O_RDWR | O_CREAT, 0644);
        if (fd > -1) {
            close(fd);
        }
    }

    if (rsc_g_bugsnag_data.usageJSON) {
        writer->addJSONElement(writer, "_usage", rsc_g_bugsnag_data.usageJSON);
    }

    if (rsc_g_bugsnag_data.onCrash) {
        rsc_g_bugsnag_data.onCrash(writer);
    }
}

// =============================================================================

// MARK: -

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterClient () <RSCBreadcrumbSink>

@property (nonatomic) RSCNotificationBreadcrumbs *notificationBreadcrumbs;

@property (weak, nonatomic) NSTimer *appLaunchTimer;

@property (nullable, retain, nonatomic) RSCrashReporterBreadcrumbs *breadcrumbStore;

@property (readwrite, nullable, nonatomic) RSCrashReporterLastRunInfo *lastRunInfo;

@property (strong, nonatomic) RSCrashReporterSessionTracker *sessionTracker;

@end

@interface RSCrashReporterClient (/* not objc_direct */)

- (void)appLaunchTimerFired:(NSTimer *)timer;

- (void)applicationWillTerminate:(NSNotification *)notification;

@end

#if RSC_HAVE_APP_HANG_DETECTION
@interface RSCrashReporterClient () <RSCAppHangDetectorDelegate>
@end
#endif

// MARK: -

#if __clang_major__ >= 11 // Xcode 10 does not like the following attribute
__attribute__((annotate("oclint:suppress[long class]")))
__attribute__((annotate("oclint:suppress[too many methods]")))
#endif
RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterClient

- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)configuration delegate:(id<RSCrashReporterNotifyDelegate> _Nullable)delegate {
    if ((self = [super init])) {
        // Take a shallow copy of the configuration
        _configuration = [configuration copy];
        
        if (!_configuration.user.id) { // populate with an autogenerated ID if no value set
            [_configuration setUser:[RSC_KSSystemInfo deviceAndAppHash] withEmail:_configuration.user.email andName:_configuration.user.name];
        }

        _featureFlagStore = [configuration.featureFlagStore copy];
        
        _state = [[RSCrashReporterMetadata alloc] initWithDictionary:@{
            RSCKeyClient: @{
                RSCKeyContext: _configuration.context ?: [NSNull null],
                RSCKeyFeatureFlags: RSCFeatureFlagStoreToJSON(_featureFlagStore),
            },
            RSCKeyUser: [_configuration.user toJson] ?: @{}
        }];
        
        _notifier = _configuration.notifier ?: [[RSCrashReporterNotifier alloc] init];

        RSCFileLocations *fileLocations = [RSCFileLocations current];
        
        NSString *crashPath = fileLocations.flagHandledCrash;
        crashSentinelPath = strdup(crashPath.fileSystemRepresentation);
        
        self.stateEventBlocks = [NSMutableArray new];
        self.extraRuntimeInfo = [NSMutableDictionary new];

        _eventUploader = [[RSCEventUploader alloc] initWithConfiguration:_configuration notifier:_notifier delegate:delegate];
        rsc_g_bugsnag_data.onCrash = (void (*)(const RSC_KSCrashReportWriter *))self.configuration.onCrashHandler;

        _breadcrumbStore = [[RSCrashReporterBreadcrumbs alloc] initWithConfiguration:self.configuration];

        // Start with a copy of the configuration metadata
        self.metadata = [[_configuration metadata] copy];
    }
    return self;
}

- (void)start {
    // Called here instead of in init so that a bad config will only throw an exception
    // from the start method.
    // MARK: - Rudder Commented
    // [self.configuration validate];
    
    // MUST be called before any code that accesses rsc_runContext
    RSCRunContextInit(RSCFileLocations.current.runContext);

    RSCCrashSentryInstall(self.configuration, BSSerializeDataCrashHandler);

    self.systemState = [[RSCrashReporterSystemState alloc] initWithConfiguration:self.configuration];

    // add metadata about app/device
    NSDictionary *systemInfo = [RSC_KSSystemInfo systemInfo];
    [self.metadata addMetadata:RSCParseAppMetadata(@{@"system": systemInfo}) toSection:RSCKeyApp];
    [self.metadata addMetadata:RSCParseDeviceMetadata(@{@"system": systemInfo}) toSection:RSCKeyDevice];

    [self computeDidCrashLastLaunch];

    if (self.configuration.telemetry & RSCTelemetryInternalErrors) {
        RSCInternalErrorReporter.sharedInstance =
        [[RSCInternalErrorReporter alloc] initWithApiKey:self.configuration.apiKey
                                                endpoint:(NSURL *_Nonnull)self.configuration.notifyURL];
    } else {
        rsc_log_debug(@"Internal error reporting was disabled in config");
    }

    NSDictionary *usage = RSCTelemetryCreateUsage(self.configuration);
    if (usage) {
        rsc_g_bugsnag_data.usageJSON = RSCCStringWithData(RSCJSONDataFromDictionary(usage, NULL));
    }

    // These files can only be overwritten once the previous contents have been read; see -generateEventForLastLaunchWithError:
    NSData *configData = RSCJSONDataFromDictionary(self.configuration.dictionaryRepresentation, NULL);
    [configData writeToFile:RSCFileLocations.current.configuration options:NSDataWritingAtomic error:nil];
    rsc_g_bugsnag_data.configJSON = RSCCStringWithData(configData);
    [self.metadata setStorageBuffer:&rsc_g_bugsnag_data.metadataJSON file:RSCFileLocations.current.metadata];
    [self.state setStorageBuffer:&rsc_g_bugsnag_data.stateJSON file:RSCFileLocations.current.state];
    [self.breadcrumbStore removeAllBreadcrumbs];

    // MARK: - Rudder Commented
/*#if RSC_HAVE_REACHABILITY
    [self setupConnectivityListener];
#endif*/

    self.notificationBreadcrumbs = [[RSCNotificationBreadcrumbs alloc] initWithConfiguration:self.configuration breadcrumbSink:self];
    [self.notificationBreadcrumbs start];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(applicationWillTerminate:)
#if TARGET_OS_OSX
                   name:NSApplicationWillTerminateNotification
#else
                   name:UIApplicationWillTerminateNotification
#endif
                 object:nil];

    self.readyForInternalCalls = YES;

    id<RSCrashReporterPlugin> reactNativePlugin = [NSClassFromString(@"RSCrashReporterReactNativePlugin") new];
    if (reactNativePlugin) {
        [self.configuration.plugins addObject:reactNativePlugin];
    }
    for (id<RSCrashReporterPlugin> plugin in self.configuration.plugins) {
        @try {
            [plugin load:self];
        } @catch (NSException *exception) {
            rsc_log_err(@"Plugin %@ threw exception in -load: %@", plugin, exception);
        }
    }
    // MARK: - Rudder Commented
    /*self.sessionTracker = [[RSCrashReporterSessionTracker alloc] initWithConfig:self.configuration client:self];
    [self.sessionTracker startWithNotificationCenter:center isInForeground:rsc_runContext->isForeground];*/

    // Record a "Metrics Loaded" message
    [self addAutoBreadcrumbOfType:RSCBreadcrumbTypeState withMessage:@"Metrics loaded" andMetadata:nil];

    if (self.configuration.launchDurationMillis > 0) {
        self.appLaunchTimer = [NSTimer scheduledTimerWithTimeInterval:(double)self.configuration.launchDurationMillis / 1000.0
                                                               target:self selector:@selector(appLaunchTimerFired:)
                                                             userInfo:nil repeats:NO];
    }
    
    if (self.lastRunInfo.crashedDuringLaunch && self.configuration.sendLaunchCrashesSynchronously) {
        [self sendLaunchCrashSynchronously];
    }
    
    if (self.eventFromLastLaunch) {
        [self.eventUploader uploadEvent:(RSCrashReporterEvent * _Nonnull)self.eventFromLastLaunch completionHandler:nil];
        self.eventFromLastLaunch = nil;
    }
    
    [self.eventUploader uploadStoredEvents];
    
#if RSC_HAVE_APP_HANG_DETECTION
    // App hang detector deliberately started after sendLaunchCrashSynchronously (which by design may itself trigger an app hang)
    // Note: RSCAppHangDetector itself checks configuration.enabledErrorTypes.appHangs
    [self startAppHangDetector];
#endif
    self.isStarted = YES;
}

- (void)appLaunchTimerFired:(__unused NSTimer *)timer {
    [self markLaunchCompleted];
}

- (void)markLaunchCompleted {
    rsc_log_debug(@"App has finished launching");
    [self.appLaunchTimer invalidate];
    rsc_runContext->isLaunching = NO;
    RSCRunContextUpdateTimestamp();
}

- (void)sendLaunchCrashSynchronously {
    if (self.configuration.sessionOrDefault.delegateQueue == NSOperationQueue.currentQueue) {
        rsc_log_warn(@"Cannot send launch crash synchronously because session.delegateQueue is set to the current queue.");
        return;
    }
    rsc_log_info(@"Sending launch crash synchronously.");
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_block_t completionHandler = ^{
        rsc_log_debug(@"Sent launch crash.");
        dispatch_semaphore_signal(semaphore);
    };
    if (self.eventFromLastLaunch) {
        [self.eventUploader uploadEvent:(RSCrashReporterEvent * _Nonnull)self.eventFromLastLaunch completionHandler:completionHandler];
        self.eventFromLastLaunch = nil;
    } else {
        [self.eventUploader uploadLatestStoredEvent:completionHandler];
    }
    if (dispatch_semaphore_wait(semaphore, deadline)) {
        rsc_log_debug(@"Timed out waiting for launch crash to be sent.");
    }
}

- (void)computeDidCrashLastLaunch {
    BOOL didCrash = NO;
    
    // Did the app crash in a way that was detected by KSCrash?
    if (rsc_kscrashstate_currentState()->crashedLastLaunch || !access(crashSentinelPath, F_OK)) {
        rsc_log_info(@"Last run terminated due to a crash.");
        unlink(crashSentinelPath);
        didCrash = YES;
    }
#if RSC_HAVE_APP_HANG_DETECTION
    // Was the app terminated while the main thread was hung?
    else if ((self.eventFromLastLaunch = [self loadAppHangEvent]).unhandled) {
        rsc_log_info(@"Last run terminated during an app hang.");
        didCrash = YES;
    }
#endif
#if !TARGET_OS_WATCH
    else if (self.configuration.autoDetectErrors && RSCRunContextWasKilled()) {
        if (RSCRunContextWasCriticalThermalState()) {
            rsc_log_info(@"Last run terminated during a critical thermal state.");
            if (self.configuration.enabledErrorTypes.thermalKills) {
                self.eventFromLastLaunch = [self generateThermalKillEvent];
            }
            didCrash = YES;
        }
#if RSC_HAVE_OOM_DETECTION
        else {
            rsc_log_info(@"Last run terminated unexpectedly; possible Out Of Memory.");
            if (self.configuration.enabledErrorTypes.ooms) {
                self.eventFromLastLaunch = [self generateOutOfMemoryEvent];
            }
            didCrash = YES;
        }
#endif
    }
#endif
    
    self.appDidCrashLastLaunch = didCrash;
    
    BOOL didCrashDuringLaunch = didCrash && RSCRunContextWasLaunching();
    if (didCrashDuringLaunch) {
        self.systemState.consecutiveLaunchCrashes++;
    } else {
        self.systemState.consecutiveLaunchCrashes = 0;
    }
    
    self.lastRunInfo = [[RSCrashReporterLastRunInfo alloc] initWithConsecutiveLaunchCrashes:self.systemState.consecutiveLaunchCrashes
                                                                            crashed:didCrash
                                                                crashedDuringLaunch:didCrashDuringLaunch];
}

- (void)setCodeBundleId:(NSString *)codeBundleId {
    _codeBundleId = codeBundleId;
    [self.state addMetadata:codeBundleId withKey:RSCKeyCodeBundleId toSection:RSCKeyApp];
    [self.systemState setCodeBundleID:codeBundleId];
    self.sessionTracker.codeBundleId = codeBundleId;
}

/**
 * Removes observers and listeners to prevent allocations when the app is terminated
 */
- (void)applicationWillTerminate:(__unused NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self.sessionTracker];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if RSC_HAVE_REACHABILITY
    [RSCConnectivity stopMonitoring];
#endif

#if RSC_HAVE_BATTERY
    RSCGetDevice().batteryMonitoringEnabled = FALSE;
#endif

#if TARGET_OS_IOS
    [[UIDEVICE currentDevice] endGeneratingDeviceOrientationNotifications];
#endif
}

// =============================================================================
// MARK: - Session Tracking
// =============================================================================

- (void)startSession {
    [self.sessionTracker startNewSession];
}

- (void)pauseSession {
    [self.sessionTracker pauseSession];
}

- (BOOL)resumeSession {
    return [self.sessionTracker resumeSession];
}

- (RSCrashReporterSession *)session {
    return self.sessionTracker.runningSession;
}

- (void)updateSession:(RSCrashReporterSession * (^)(RSCrashReporterSession *session))block {
    self.sessionTracker.currentSession =  block(self.sessionTracker.currentSession);
    RSCSessionUpdateRunContext(self.sessionTracker.runningSession);
}

// =============================================================================
// MARK: - Connectivity Listener
// =============================================================================

#if RSC_HAVE_REACHABILITY
/**
 * Monitor the RSCrashReporter endpoint to detect changes in connectivity,
 * flush pending events when (re)connected and report connectivity
 * changes as breadcrumbs, if configured to do so.
 */
- (void)setupConnectivityListener {
    NSURL *url = self.configuration.notifyURL;

    // ARC Reference - 4.2 __weak Semantics
    // http://clang.llvm.org/docs/AutomaticReferenceCounting.html
    // Avoid potential strong reference cycle between the 'client' instance and
    // the RSCConnectivity static storage.
    __weak typeof(self) weakSelf = self;
    [RSCConnectivity monitorURL:url
                  usingCallback:^(BOOL connected, NSString *connectionType) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (connected) {
            [strongSelf.eventUploader uploadStoredEvents];
            [strongSelf.sessionTracker.sessionUploader processStoredSessions];
        }

        [strongSelf addAutoBreadcrumbOfType:RSCBreadcrumbTypeState
                                withMessage:@"Connectivity changed"
                                andMetadata:@{@"type": connectionType}];
    }];
}
#endif

// =============================================================================
// MARK: - Breadcrumbs
// =============================================================================

- (void)leaveBreadcrumbWithMessage:(NSString *_Nonnull)message {
    [self leaveBreadcrumbWithMessage:message metadata:nil andType:RSCBreadcrumbTypeManual];
}

- (void)leaveBreadcrumbForNotificationName:(NSString *_Nonnull)notificationName {
    [self.notificationBreadcrumbs startListeningForStateChangeNotification:notificationName];
}

- (void)leaveBreadcrumbWithMessage:(NSString *_Nonnull)message
                          metadata:(NSDictionary *_Nullable)metadata
                           andType:(RSCBreadcrumbType)type {
    NSDictionary *JSONMetadata = RSCJSONDictionary(metadata ?: @{});
    if (JSONMetadata != metadata && metadata) {
        rsc_log_warn("Breadcrumb metadata is not a valid JSON object: %@", metadata);
    }
    
    RSCrashReporterBreadcrumb *breadcrumb = [RSCrashReporterBreadcrumb new];
    breadcrumb.message = message;
    breadcrumb.metadata = JSONMetadata ?: @{};
    breadcrumb.type = type;
    [self.breadcrumbStore addBreadcrumb:breadcrumb];
    
    RSCRunContextUpdateTimestamp();
}

- (void)leaveNetworkRequestBreadcrumbForTask:(NSURLSessionTask *)task
                                     metrics:(NSURLSessionTaskMetrics *)metrics {
    if (!(self.configuration.enabledBreadcrumbTypes & RSCEnabledBreadcrumbTypeRequest)) {
        return;
    }
    RSCrashReporterBreadcrumb *breadcrumb = RSCNetworkBreadcrumbWithTaskMetrics(task, metrics);
    if (!breadcrumb) {
        return;
    }
    [self.breadcrumbStore addBreadcrumb:breadcrumb];
    RSCRunContextUpdateTimestamp();
}

- (NSArray<RSCrashReporterBreadcrumb *> *)breadcrumbs {
    return self.breadcrumbStore.breadcrumbs ?: @[];
}

// =============================================================================
// MARK: - User
// =============================================================================

- (RSCrashReporterUser *)user {
    @synchronized (self.configuration) {
        return self.configuration.user;
    }
}

- (void)setUser:(NSString *)userId withEmail:(NSString *)email andName:(NSString *)name {
    @synchronized (self.configuration) {
        [self.configuration setUser:userId withEmail:email andName:name];
        [self.state addMetadata:[self.configuration.user toJson] toSection:RSCKeyUser];
        if (self.observer) {
            self.observer(RSCClientObserverUpdateUser, self.user);
        }
    }
}

// =============================================================================
// MARK: - onSession
// =============================================================================

- (nonnull RSCrashReporterOnSessionRef)addOnSessionBlock:(nonnull RSCrashReporterOnSessionBlock)block {
    return [self.configuration addOnSessionBlock:block];
}

- (void)removeOnSession:(nonnull RSCrashReporterOnSessionRef)callback {
    [self.configuration removeOnSession:callback];
}

- (void)removeOnSessionBlock:(RSCrashReporterOnSessionBlock _Nonnull )block {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self.configuration removeOnSessionBlock:block];
#pragma clang diagnostic pop
}

// =============================================================================
// MARK: - onBreadcrumb
// =============================================================================

- (nonnull RSCrashReporterOnBreadcrumbRef)addOnBreadcrumbBlock:(nonnull RSCrashReporterOnBreadcrumbBlock)block {
    return [self.configuration addOnBreadcrumbBlock:block];
}

- (void)removeOnBreadcrumb:(nonnull RSCrashReporterOnBreadcrumbRef)callback {
    [self.configuration removeOnBreadcrumb:callback];
}

- (void)removeOnBreadcrumbBlock:(RSCrashReporterOnBreadcrumbBlock _Nonnull)block {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self.configuration removeOnBreadcrumbBlock:block];
#pragma clang diagnostic pop
}

// =============================================================================
// MARK: - Context
// =============================================================================

- (void)setContext:(nullable NSString *)context {
    self.configuration.context = context;
    [self.state addMetadata:context withKey:RSCKeyContext toSection:RSCKeyClient];
    if (self.observer) {
        self.observer(RSCClientObserverUpdateContext, context);
    }
}

- (NSString *)context {
    return self.configuration.context;
}

// MARK: - Notify

// note - some duplication between notifyError calls is required to ensure
// the same number of stackframes are used for each call.
// see notify:handledState:block for further info

- (void)notifyError:(NSError *)error {
    rsc_log_debug(@"%s %@", __PRETTY_FUNCTION__, error);
    [self notifyErrorOrException:error block:nil];
}

- (void)notifyError:(NSError *)error block:(RSCrashReporterOnErrorBlock)block {
    rsc_log_debug(@"%s %@", __PRETTY_FUNCTION__, error);
    [self notifyErrorOrException:error block:block];
}

- (void)notify:(NSException *)exception {
    rsc_log_debug(@"%s %@", __PRETTY_FUNCTION__, exception);
    [self notifyErrorOrException:exception block:nil];
}

- (void)notify:(NSException *)exception block:(RSCrashReporterOnErrorBlock)block {
    rsc_log_debug(@"%s %@", __PRETTY_FUNCTION__, exception);
    [self notifyErrorOrException:exception block:block];
}

// MARK: - Notify (Internal)

- (void)notifyErrorOrException:(id)errorOrException block:(RSCrashReporterOnErrorBlock)block {
    NSDictionary *systemInfo = [RSC_KSSystemInfo systemInfo];
    RSCrashReporterMetadata *metadata = [self.metadata copy];
    
    NSArray<NSNumber *> *callStack = nil;
    NSString *context = self.context;
    NSString *errorClass = nil;
    NSString *errorMessage = nil;
    RSCrashReporterHandledState *handledState = nil;
    
    if ([errorOrException isKindOfClass:[NSException class]]) {
        NSException *exception = errorOrException;
        callStack = exception.callStackReturnAddresses;
        errorClass = exception.name;
        errorMessage = exception.reason;
        handledState = [RSCrashReporterHandledState handledStateWithSeverityReason:HandledException];
        NSMutableDictionary *meta = [NSMutableDictionary dictionary];
        NSDictionary *userInfo = exception.userInfo ? RSCJSONDictionary((NSDictionary *_Nonnull)exception.userInfo) : nil;
        meta[@"nsexception"] = [NSDictionary dictionaryWithObjectsAndKeys:exception.name, @"name", userInfo, @"userInfo", nil];
        meta[@"reason"] = exception.reason;
        meta[@"type"] = @"nsexception";
        [metadata addMetadata:meta toSection:@"error"];
    }
    else if ([errorOrException isKindOfClass:[NSError class]]) {
        NSError *error = errorOrException;
        if (!context) {
            context = [NSString stringWithFormat:@"%@ (%ld)", error.domain, (long)error.code];
        }
        errorClass = NSStringFromClass([error class]);
        errorMessage = error.localizedDescription;
        handledState = [RSCrashReporterHandledState handledStateWithSeverityReason:HandledError];
        NSMutableDictionary *meta = [NSMutableDictionary dictionary];
        meta[@"code"] = @(error.code);
        meta[@"domain"] = error.domain;
        meta[@"reason"] = error.localizedFailureReason;
        meta[@"userInfo"] = RSCJSONDictionary(error.userInfo);
        [metadata addMetadata:meta toSection:@"nserror"];
    }
    else {
        rsc_log_warn(@"Unsupported error type passed to notify: %@", NSStringFromClass([errorOrException class]));
        return;
    }
    
    /**
     * Stack frames starting from this one are removed by setting the depth.
     * This helps remove bugsnag frames from showing in NSErrors as their
     * trace is synthesized.
     *
     * For example, for [RSCrashReporter notifyError:block:], bugsnag adds the following
     * frames which must be removed:
     *
     * 1. +[RSCrashReporter notifyError:block:]
     * 2. -[RSCrashReporterClient notifyError:block:]
     * 3. -[RSCrashReporterClient notify:handledState:block:]
     */
    NSUInteger depth = 3;
    
    if (!callStack.count) {
        // If the NSException was not raised by the Objective-C runtime, it will be missing a call stack.
        // Use the current call stack instead.
        callStack = RSCArraySubarrayFromIndex(NSThread.callStackReturnAddresses, depth);
    }
    
#if RSC_HAVE_MACH_THREADS
    BOOL recordAllThreads = self.configuration.sendThreads == RSCThreadSendPolicyAlways;
    NSArray *threads = recordAllThreads ? [RSCrashReporterThread allThreads:YES callStackReturnAddresses:callStack] : @[];
#else
    NSArray *threads = @[];
#endif
    
    NSArray<RSCrashReporterStackframe *> *stacktrace = [RSCrashReporterStackframe stackframesWithCallStackReturnAddresses:callStack];
    
    RSCrashReporterError *error = [[RSCrashReporterError alloc] initWithErrorClass:errorClass
                                                      errorMessage:errorMessage
                                                         errorType:RSCErrorTypeCocoa
                                                        stacktrace:stacktrace];

    RSCrashReporterEvent *event = [[RSCrashReporterEvent alloc] initWithApp:[self generateAppWithState:systemInfo]
                                                     device:[self generateDeviceWithState:systemInfo]
                                               handledState:handledState
                                                       user:[self.user withId]
                                                   metadata:metadata
                                                breadcrumbs:[self breadcrumbs]
                                                     errors:@[error]
                                                    threads:threads
                                                    session:nil /* the session's event counts have not yet been incremented! */];
    event.apiKey = self.configuration.apiKey;
    event.context = context;
    event.originalError = errorOrException;

    [self notifyInternal:event block:block];
}

/**
 *  Notify RSCrashReporter of an exception. Used for user-reported (handled) errors, React Native, and Unity.
 *
 *  @param event    the event
 *  @param block     Configuration block for adding additional report information
 */
- (void)notifyInternal:(RSCrashReporterEvent *_Nonnull)event
                 block:(RSCrashReporterOnErrorBlock)block
{
    // Checks whether releaseStage is in enabledReleaseStages, blocking onError callback from running if it is not.
    if (!self.configuration.shouldSendReports || ![event shouldBeSent]) {
        rsc_log_info("Discarding error because releaseStage '%@' not in enabledReleaseStages", self.configuration.releaseStage);
        return;
    }
    
    NSString *errorClass = event.errors.firstObject.errorClass;
    if ([self.configuration shouldDiscardErrorClass:errorClass]) {
        rsc_log_info(@"Discarding event because errorClass \"%@\" matched configuration.discardClasses", errorClass);
        return;
    }
    
#if TARGET_OS_WATCH
    // Update RSCRunContext because we cannot observe battery level or state on watchOS :-(
    rsc_runContext->batteryLevel = RSCGetDevice().batteryLevel;
    rsc_runContext->batteryState = RSCGetDevice().batteryState;
#endif
    [event.metadata addMetadata:RSCAppMetadataFromRunContext(rsc_runContext) toSection:RSCKeyApp];
    [event.metadata addMetadata:RSCDeviceMetadataFromRunContext(rsc_runContext) toSection:RSCKeyDevice];

    // App hang events will already contain feature flags
    if (!event.featureFlagStore.count) {
        @synchronized (self.featureFlagStore) {
            event.featureFlagStore = [self.featureFlagStore copy];
        }
    }

    // event.user = [event.user withId];

    BOOL originalUnhandledValue = event.unhandled;
    @try {
        if (block != nil && !block(event)) { // skip notifying if callback false
            return;
        }
    } @catch (NSException *exception) {
        rsc_log_err(@"Error from onError callback: %@", exception);
    }
    if (event.unhandled != originalUnhandledValue) {
        [event notifyUnhandledOverridden];
    }

    [self.sessionTracker incrementEventCountUnhandled:event.handledState.unhandled];
    event.session = self.sessionTracker.runningSession;

    event.usage = RSCTelemetryCreateUsage(self.configuration);

    if (event.handledState.originalUnhandledValue) {
        // Unhandled Javscript exceptions from React Native result in the app being terminated shortly after the
        // call to notifyInternal, so the event needs to be persisted to disk for sending in the next session.
        // The fatal "RCTFatalException" / "Unhandled JS Exception" is explicitly ignored by
        // RSCrashReporterReactNativePlugin's OnSendErrorBlock.
        [self.eventUploader storeEvent:event];
        // Replicate previous delivery mechanism's behaviour of waiting 1 second before delivering the event.
        // This should prevent potential duplicate uploads of unhandled errors where the app subsequently terminates.
        [self.eventUploader uploadStoredEventsAfterDelay:1];
    } else {
        [self.eventUploader uploadEvent:event completionHandler:nil];
    }

    [self addAutoBreadcrumbForEvent:event];
}

// MARK: - Breadcrumbs

- (void)addAutoBreadcrumbForEvent:(RSCrashReporterEvent *)event {
    // A basic set of event metadata
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[RSCKeyErrorClass] = event.errors[0].errorClass;
    metadata[RSCKeyUnhandled] = @(event.handledState.unhandled);
    metadata[RSCKeySeverity] = RSCFormatSeverity(event.severity);

    // Only include the eventMessage if it contains something
    NSString *eventMessage = event.errors[0].errorMessage;
    if (eventMessage.length) {
        [metadata setValue:eventMessage forKey:RSCKeyName];
    }

    [self addAutoBreadcrumbOfType:RSCBreadcrumbTypeError
                      withMessage:event.errors[0].errorClass ?: @""
                      andMetadata:metadata];
}

/**
 * A convenience safe-wrapper for conditionally recording automatic breadcrumbs
 * based on the configuration.
 *
 * @param breadcrumbType The type of breadcrumb
 * @param message The breadcrumb message
 * @param metadata The breadcrumb metadata.  If nil this is substituted by an empty dictionary.
 */
- (void)addAutoBreadcrumbOfType:(RSCBreadcrumbType)breadcrumbType
                    withMessage:(NSString * _Nonnull)message
                    andMetadata:(NSDictionary *)metadata
{
    if ([[self configuration] shouldRecordBreadcrumbType:breadcrumbType]) {
        [self leaveBreadcrumbWithMessage:message metadata:metadata andType:breadcrumbType];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// MARK: - <RSCrashReporterFeatureFlagStore>

- (void)addFeatureFlagWithName:(NSString *)name variant:(nullable NSString *)variant {
    @synchronized (self.featureFlagStore) {
        RSCFeatureFlagStoreAddFeatureFlag(self.featureFlagStore, name, variant);
        [self.state addMetadata:RSCFeatureFlagStoreToJSON(self.featureFlagStore) withKey:RSCKeyFeatureFlags toSection:RSCKeyClient];
    }
    if (self.observer) {
        self.observer(RSCClientObserverAddFeatureFlag, [RSCrashReporterFeatureFlag flagWithName:name variant:variant]);
    }
}

- (void)addFeatureFlagWithName:(NSString *)name {
    @synchronized (self.featureFlagStore) {
        RSCFeatureFlagStoreAddFeatureFlag(self.featureFlagStore, name, nil);
        [self.state addMetadata:RSCFeatureFlagStoreToJSON(self.featureFlagStore) withKey:RSCKeyFeatureFlags toSection:RSCKeyClient];
    }
    if (self.observer) {
        self.observer(RSCClientObserverAddFeatureFlag, [RSCrashReporterFeatureFlag flagWithName:name]);
    }
}

- (void)addFeatureFlags:(NSArray<RSCrashReporterFeatureFlag *> *)featureFlags {
    @synchronized (self.featureFlagStore) {
        RSCFeatureFlagStoreAddFeatureFlags(self.featureFlagStore, featureFlags);
        [self.state addMetadata:RSCFeatureFlagStoreToJSON(self.featureFlagStore) withKey:RSCKeyFeatureFlags toSection:RSCKeyClient];
    }
    if (self.observer) {
        for (RSCrashReporterFeatureFlag *featureFlag in featureFlags) {
            self.observer(RSCClientObserverAddFeatureFlag, featureFlag);
        }
    }
}

- (void)clearFeatureFlagWithName:(NSString *)name {
    @synchronized (self.featureFlagStore) {
        RSCFeatureFlagStoreClear(self.featureFlagStore, name);
        [self.state addMetadata:RSCFeatureFlagStoreToJSON(self.featureFlagStore) withKey:RSCKeyFeatureFlags toSection:RSCKeyClient];
    }
    if (self.observer) {
        self.observer(RSCClientObserverClearFeatureFlag, name);
    }
}

- (void)clearFeatureFlags {
    @synchronized (self.featureFlagStore) {
        RSCFeatureFlagStoreClear(self.featureFlagStore, nil);
        [self.state addMetadata:RSCFeatureFlagStoreToJSON(self.featureFlagStore) withKey:RSCKeyFeatureFlags toSection:RSCKeyClient];
    }
    if (self.observer) {
        self.observer(RSCClientObserverClearFeatureFlag, nil);
    }
}

// MARK: - <RSCrashReporterMetadataStore>

- (void)addMetadata:(NSDictionary *_Nonnull)metadata
          toSection:(NSString *_Nonnull)sectionName
{
    [self.metadata addMetadata:metadata toSection:sectionName];
}

- (void)addMetadata:(id _Nullable)metadata
            withKey:(NSString *_Nonnull)key
          toSection:(NSString *_Nonnull)sectionName
{
    [self.metadata addMetadata:metadata withKey:key toSection:sectionName];
}

- (id _Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName
                               withKey:(NSString *_Nonnull)key
{
    return [self.metadata getMetadataFromSection:sectionName withKey:key];
}

- (NSMutableDictionary *_Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName
{
    return [self.metadata getMetadataFromSection:sectionName];
}

- (void)clearMetadataFromSection:(NSString *_Nonnull)sectionName
{
    [self.metadata clearMetadataFromSection:sectionName];
}

- (void)clearMetadataFromSection:(NSString *_Nonnull)sectionName
                       withKey:(NSString *_Nonnull)key
{
    [self.metadata clearMetadataFromSection:sectionName withKey:key];
}

// MARK: - event data population

- (RSCrashReporterAppWithState *)generateAppWithState:(NSDictionary *)systemInfo {
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appWithDictionary:@{RSCKeySystem: systemInfo}
                                                               config:self.configuration codeBundleId:self.codeBundleId];
    app.isLaunching = rsc_runContext->isLaunching;
    return app;
}

- (RSCrashReporterDeviceWithState *)generateDeviceWithState:(NSDictionary *)systemInfo {
    RSCrashReporterDeviceWithState *device = [RSCrashReporterDeviceWithState deviceWithKSCrashReport:@{RSCKeySystem: systemInfo}];
    device.time = [NSDate date]; // default to current time for handled errors
    [device appendRuntimeInfo:self.extraRuntimeInfo];
#if TARGET_OS_IOS
    device.orientation = RSCStringFromDeviceOrientation(rsc_runContext->lastKnownOrientation);
#endif
    return device;
}

// MARK: - methods used by React Native

- (void)addRuntimeVersionInfo:(NSString *)info
                      withKey:(NSString *)key {
    [self.sessionTracker addRuntimeVersionInfo:info
                                       withKey:key];
    if (info != nil && key != nil) {
        self.extraRuntimeInfo[key] = info;
    }
    [self.state addMetadata:self.extraRuntimeInfo withKey:RSCKeyExtraRuntimeInfo toSection:RSCKeyDevice];
}

- (void)setObserver:(RSCClientObserver)observer {
    _observer = observer;
    if (observer) {
        observer(RSCClientObserverUpdateContext, self.context);
        observer(RSCClientObserverUpdateUser, self.user);
        
        observer(RSCClientObserverUpdateMetadata, self.metadata);
        self.metadata.observer = ^(RSCrashReporterMetadata *metadata) {
            observer(RSCClientObserverUpdateMetadata, metadata);
        };
        
        @synchronized (self.featureFlagStore) {
            for (RSCrashReporterFeatureFlag *flag in self.featureFlagStore.allFlags) {
                observer(RSCClientObserverAddFeatureFlag, flag);
            }
        }
    } else {
        self.metadata.observer = nil;
    }
}

// MARK: - App Hangs

#if RSC_HAVE_APP_HANG_DETECTION
- (void)startAppHangDetector {
    [NSFileManager.defaultManager removeItemAtPath:RSCFileLocations.current.appHangEvent error:nil];

    self.appHangDetector = [[RSCAppHangDetector alloc] init];
    [self.appHangDetector startWithDelegate:self];
}
#endif

- (void)appHangDetectedAtDate:(NSDate *)date withThreads:(NSArray<RSCrashReporterThread *> *)threads systemInfo:(NSDictionary *)systemInfo {
#if RSC_HAVE_APP_HANG_DETECTION
    NSString *message = [NSString stringWithFormat:@"The app's main thread failed to respond to an event within %d milliseconds",
                         (int)self.configuration.appHangThresholdMillis];

    RSCrashReporterError *error =
    [[RSCrashReporterError alloc] initWithErrorClass:@"App Hang"
                                errorMessage:message
                                   errorType:RSCErrorTypeCocoa
                                  stacktrace:threads.firstObject.stacktrace];

    RSCrashReporterHandledState *handledState =
    [[RSCrashReporterHandledState alloc] initWithSeverityReason:AppHang
                                               severity:RSCSeverityWarning
                                              unhandled:NO
                                    unhandledOverridden:NO
                                              attrValue:nil];

    RSCrashReporterAppWithState *app = [self generateAppWithState:systemInfo];

    RSCrashReporterDeviceWithState *device = [self generateDeviceWithState:systemInfo];
    device.time = date;

    NSArray<RSCrashReporterBreadcrumb *> *breadcrumbs = [self.breadcrumbStore breadcrumbsBeforeDate:date];

    RSCrashReporterMetadata *metadata = [self.metadata copy];

    [metadata addMetadata:RSCAppMetadataFromRunContext(rsc_runContext) toSection:RSCKeyApp];
    [metadata addMetadata:RSCDeviceMetadataFromRunContext(rsc_runContext) toSection:RSCKeyDevice];

    self.appHangEvent =
    [[RSCrashReporterEvent alloc] initWithApp:app
                               device:device
                         handledState:handledState
                                 user:[self.user withId]
                             metadata:metadata
                          breadcrumbs:breadcrumbs
                               errors:@[error]
                              threads:threads
                              session:self.sessionTracker.runningSession];

    self.appHangEvent.context = self.context;

    @synchronized (self.featureFlagStore) {
        self.appHangEvent.featureFlagStore = [self.featureFlagStore copy];
    }
    
    [self.appHangEvent symbolicateIfNeeded];
    
    NSError *writeError = nil;
    NSDictionary *json = [self.appHangEvent toJsonWithRedactedKeys:self.configuration.redactedKeys];
    if (!RSCJSONWriteToFileAtomically(json, RSCFileLocations.current.appHangEvent, &writeError)) {
        rsc_log_err(@"Could not write app_hang.json: %@", writeError);
    }
#endif
}

- (void)appHangEnded {
#if RSC_HAVE_APP_HANG_DETECTION
    NSError *error = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:RSCFileLocations.current.appHangEvent error:&error]) {
        rsc_log_err(@"Could not delete app_hang.json: %@", error);
    }

    const BOOL fatalOnly = self.configuration.appHangThresholdMillis == RSCrashReporterAppHangThresholdFatalOnly;
    if (!fatalOnly && self.appHangEvent) {
        [self notifyInternal:(RSCrashReporterEvent * _Nonnull)self.appHangEvent block:nil];
    }
    self.appHangEvent = nil;
#endif
}

#if RSC_HAVE_APP_HANG_DETECTION
- (nullable RSCrashReporterEvent *)loadAppHangEvent {
    NSError *error = nil;
    NSDictionary *json = RSCJSONDictionaryFromFile(RSCFileLocations.current.appHangEvent, 0, &error);
    if (!json) {
        if (!(error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError)) {
            rsc_log_err(@"Could not read app_hang.json: %@", error);
        }
        return nil;
    }

    RSCrashReporterEvent *event = [[RSCrashReporterEvent alloc] initWithJson:json];
    if (!event) {
        rsc_log_err(@"Could not parse app_hang.json");
        return nil;
    }

    // Receipt of the willTerminateNotification indicates that an app hang was not the cause of the termination, so treat as non-fatal.
    if (RSCRunContextWasTerminating()) {
        if (self.configuration.appHangThresholdMillis == RSCrashReporterAppHangThresholdFatalOnly) {
            return nil;
        }
        event.session.handledCount++;
        return event;
    }

    // Update event to reflect that the app hang was fatal.
    event.errors.firstObject.errorMessage = @"The app was terminated while unresponsive";
    // Cannot set event.severity directly because that sets severityReason.type to "userCallbackSetSeverity"
    event.handledState = [[RSCrashReporterHandledState alloc] initWithSeverityReason:AppHang
                                                                    severity:RSCSeverityError
                                                                   unhandled:YES
                                                         unhandledOverridden:NO
                                                                   attrValue:nil];
    event.session.unhandledCount++;

    return event;
}
#endif

// MARK: - Event generation

- (nullable RSCrashReporterEvent *)generateOutOfMemoryEvent {
    return [self generateEventForLastLaunchWithError:
            [[RSCrashReporterError alloc] initWithErrorClass:@"Out Of Memory"
                                        errorMessage:@"The app was likely terminated by the operating system while in the foreground"
                                           errorType:RSCErrorTypeCocoa
                                          stacktrace:nil]
                                        handledState:[RSCrashReporterHandledState handledStateWithSeverityReason:LikelyOutOfMemory]];
}

- (nullable RSCrashReporterEvent *)generateThermalKillEvent {
    return [self generateEventForLastLaunchWithError:
            [[RSCrashReporterError alloc] initWithErrorClass:@"Thermal Kill"
                                        errorMessage:@"The app was terminated by the operating system due to a critical thermal state"
                                           errorType:RSCErrorTypeCocoa
                                          stacktrace:nil]
                                        handledState:[RSCrashReporterHandledState handledStateWithSeverityReason:ThermalKill]];
}

- (nullable RSCrashReporterEvent *)generateEventForLastLaunchWithError:(RSCrashReporterError *)error handledState:(RSCrashReporterHandledState *)handledState {
    if (!rsc_lastRunContext) {
        return nil;
    }
    
    NSDictionary *stateDict = RSCJSONDictionaryFromFile(RSCFileLocations.current.state, 0, nil);

    NSDictionary *appDict = self.systemState.lastLaunchState[SYSTEMSTATE_KEY_APP];
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appFromJson:appDict];
    app.dsymUuid = appDict[RSCKeyMachoUUID];
    app.inForeground = rsc_lastRunContext->isForeground;
    app.isLaunching = rsc_lastRunContext->isLaunching;

    NSDictionary *configDict = RSCJSONDictionaryFromFile(RSCFileLocations.current.configuration, 0, nil);
    if (configDict) {
        [app setValuesFromConfiguration:[[RSCrashReporterConfiguration alloc] initWithDictionaryRepresentation:configDict]];
    }

    NSDictionary *deviceDict = self.systemState.lastLaunchState[SYSTEMSTATE_KEY_DEVICE];
    RSCrashReporterDeviceWithState *device = [RSCrashReporterDeviceWithState deviceFromJson:deviceDict];
    device.manufacturer = @"Apple";
#if TARGET_OS_IOS
    device.orientation = RSCStringFromDeviceOrientation(rsc_lastRunContext->lastKnownOrientation);
#endif
    if (rsc_lastRunContext->timestamp > 0) {
        device.time = [NSDate dateWithTimeIntervalSinceReferenceDate:rsc_lastRunContext->timestamp];
    }
    device.freeMemory = @(rsc_lastRunContext->hostMemoryFree);

    NSDictionary *metadataDict = RSCJSONDictionaryFromFile(RSCFileLocations.current.metadata, 0, nil);
    RSCrashReporterMetadata *metadata = [[RSCrashReporterMetadata alloc] initWithDictionary:metadataDict ?: @{}];
    
    [metadata addMetadata:RSCAppMetadataFromRunContext((const struct RSCRunContext *_Nonnull)rsc_lastRunContext) toSection:RSCKeyApp];
    [metadata addMetadata:RSCDeviceMetadataFromRunContext((const struct RSCRunContext *_Nonnull)rsc_lastRunContext) toSection:RSCKeyDevice];
    
#if RSC_HAVE_OOM_DETECTION
    if (RSCRunContextWasMemoryWarning()) {
        [metadata addMetadata:@YES
                      withKey:RSCKeyLowMemoryWarning
                    toSection:RSCKeyDevice];
    }
#endif

    NSDictionary *userDict = stateDict[RSCKeyUser];
    RSCrashReporterUser *user = [[RSCrashReporterUser alloc] initWithDictionary:userDict];

    RSCrashReporterSession *session = RSCSessionFromLastRunContext(app, device, user);
    session.unhandledCount += 1;

    RSCrashReporterEvent *event =
    [[RSCrashReporterEvent alloc] initWithApp:app
                               device:device
                         handledState:handledState
                                 user:user
                             metadata:metadata
                          breadcrumbs:[self.breadcrumbStore cachedBreadcrumbs] ?: @[]
                               errors:@[error]
                              threads:@[]
                              session:session];

    event.context = stateDict[RSCKeyClient][RSCKeyContext];

    id featureFlags = stateDict[RSCKeyClient][RSCKeyFeatureFlags];
    event.featureFlagStore = RSCFeatureFlagStoreFromJSON(featureFlags);

    return event;
}

@end
