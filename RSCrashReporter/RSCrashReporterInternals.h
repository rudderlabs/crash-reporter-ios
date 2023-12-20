//
//  RSCrashReporterInternals.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 31/08/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import <RSCrashReporter/RSCrashReporter.h>

/**
 * ** WARNING **
 *
 * The interfaces declared in this header file are for use by RSCrashReporter's other
 * platform notifiers such as bugsnag-cocos2ds, bugsnag-flutter, bugsnag-js,
 * bugsnag-unreal and bugsnag-unity.
 *
 * These interfaces may be changed, renamed or removed without warning in minor
 * or bugfix releases, and should not be used by projects outside of RSCrashReporter.
 */

#import "RSCrashReporterHandledState.h"
#import "RSCrashReporterNotifier.h"

@interface RSCFeatureFlagStore : NSObject <NSCopying>
@end

NS_ASSUME_NONNULL_BEGIN

#pragma mark -

@interface RSCrashReporter ()

@property (class, readonly, nonatomic) BOOL bugsnagReadyForInternalCalls;

@property (class, readonly, nonatomic) RSCrashReporterClient *client;

@end

#pragma mark -

@interface RSCrashReporterAppWithState ()

+ (RSCrashReporterAppWithState *)appFromJson:(NSDictionary *)json;

- (NSDictionary *)toDict;

@end

#pragma mark -

@interface RSCrashReporterBreadcrumb ()

+ (nullable instancetype)breadcrumbFromDict:(NSDictionary *)dict;

- (nullable NSDictionary *)objectValue;

@end

RSCRASHREPORTER_EXTERN NSString * RSCBreadcrumbTypeValue(RSCBreadcrumbType type);

RSCRASHREPORTER_EXTERN RSCBreadcrumbType RSCBreadcrumbTypeFromString(NSString * _Nullable value);

#pragma mark -

typedef NS_ENUM(NSInteger, RSCClientObserverEvent) {
    RSCClientObserverAddFeatureFlag,    // value: RSCrashReporterFeatureFlag
    RSCClientObserverClearFeatureFlag,  // value: NSString
    RSCClientObserverUpdateContext,     // value: NSString
    RSCClientObserverUpdateMetadata,    // value: RSCrashReporterMetadata
    RSCClientObserverUpdateUser,        // value: RSCrashReporterUser
};

typedef void (^ RSCClientObserver)(RSCClientObserverEvent event, _Nullable id value);

@interface RSCrashReporterClient ()

@property (nullable, nonatomic) NSString *codeBundleId;

@property (retain, nonatomic) RSCrashReporterConfiguration *configuration;

@property (readonly, nonatomic) RSCFeatureFlagStore *featureFlagStore;

@property (strong, nonatomic) RSCrashReporterMetadata *metadata;

@property (readonly, nonatomic) RSCrashReporterNotifier *notifier;

@property (nullable, nonatomic) RSCClientObserver observer;

/// The currently active (not paused) session.
@property (readonly, nullable, nonatomic) RSCrashReporterSession *session;

- (void)addRuntimeVersionInfo:(NSString *)info withKey:(NSString *)key;

- (RSCrashReporterAppWithState *)generateAppWithState:(NSDictionary *)systemInfo;

- (RSCrashReporterDeviceWithState *)generateDeviceWithState:(NSDictionary *)systemInfo;

- (void)notifyInternal:(RSCrashReporterEvent *)event block:(nullable RSCrashReporterOnErrorBlock)block;

- (void)updateSession:(RSCrashReporterSession * _Nullable (^)(RSCrashReporterSession * _Nullable session))block;

@end

#pragma mark -

@interface RSCrashReporterConfiguration ()

@property (nullable, nonatomic) RSCrashReporterNotifier *notifier;

@property (nonatomic) NSMutableArray<RSCrashReporterOnBreadcrumbBlock> *onBreadcrumbBlocks;

@property (nonatomic) NSMutableArray<RSCrashReporterOnSendErrorBlock> *onSendBlocks;

@property (nonatomic) NSMutableArray<RSCrashReporterOnSessionBlock> *onSessionBlocks;

@end

#pragma mark -

@interface RSCrashReporterDeviceWithState ()

+ (instancetype)deviceFromJson:(NSDictionary *)json;

- (NSDictionary *)toDictionary;

@end

#pragma mark -

@interface RSCrashReporterError ()

+ (RSCrashReporterError *)errorFromJson:(NSDictionary *)json;

- (instancetype)initWithErrorClass:(NSString *)errorClass
                      errorMessage:(nullable NSString *)errorMessage
                         errorType:(RSCErrorType)errorType
                        stacktrace:(nullable NSArray<RSCrashReporterStackframe *> *)stacktrace;

@end

#pragma mark -

@interface RSCrashReporterEvent ()

- (instancetype)initWithApp:(RSCrashReporterAppWithState *)app
                     device:(RSCrashReporterDeviceWithState *)device
               handledState:(RSCrashReporterHandledState *)handledState
                       user:(RSCrashReporterUser *)user
                   metadata:(RSCrashReporterMetadata *)metadata
                breadcrumbs:(NSArray<RSCrashReporterBreadcrumb *> *)breadcrumbs
                     errors:(NSArray<RSCrashReporterError *> *)errors
                    threads:(NSArray<RSCrashReporterThread *> *)threads
                    session:(nullable RSCrashReporterSession *)session;

- (instancetype)initWithJson:(NSDictionary *)json;

- (void)attachCustomStacktrace:(NSArray *)frames withType:(NSString *)type;

- (void)symbolicateIfNeeded;

- (NSDictionary *)toJsonWithRedactedKeys:(nullable NSSet *)redactedKeys;

@property (readwrite, strong, nonnull, nonatomic) RSCFeatureFlagStore *featureFlagStore;

@end

#pragma mark -

@interface RSCrashReporterMetadata ()

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@property (readonly, nonatomic) NSMutableDictionary *dictionary;

- (NSDictionary *)toDictionary;

@end

#pragma mark -

@interface RSCrashReporterSession ()

@property (readwrite, nonatomic) RSCrashReporterApp *app;

@property (readwrite, nonatomic) RSCrashReporterDevice *device;

@property (nonatomic) NSUInteger handledCount;

@property (nonatomic) NSUInteger unhandledCount;

@end

#pragma mark -

@interface RSCrashReporterStackframe ()

+ (instancetype)frameFromJson:(NSDictionary *)json;

@property (copy, nullable, nonatomic) NSString *codeIdentifier;
@property (strong, nullable, nonatomic) NSNumber *columnNumber;
@property (copy, nullable, nonatomic) NSString *file;
@property (strong, nullable, nonatomic) NSNumber *inProject;
@property (strong, nullable, nonatomic) NSNumber *lineNumber;

/// Populates the method and symbolAddress via `dladdr()` if this object was created from a backtrace or callstack.
/// This can be a slow operation, so should be performed on a background thread.
- (void)symbolicateIfNeeded;

- (NSDictionary *)toDictionary;

@end

#pragma mark -

@interface RSCrashReporterThread ()

+ (NSArray<RSCrashReporterThread *> *)allThreads:(BOOL)allThreads callStackReturnAddresses:(NSArray<NSNumber *> *)callStackReturnAddresses;

+ (NSMutableArray *)serializeThreads:(nullable NSArray<RSCrashReporterThread *> *)threads;

+ (instancetype)threadFromJson:(NSDictionary *)json;

@end

#pragma mark -

@interface RSCrashReporterUser ()

- (instancetype)initWithDictionary:(nullable NSDictionary *)dict;

- (NSDictionary *)toJson;

@end

#pragma mark -

RSCRASHREPORTER_EXTERN NSString * RSCGetDefaultDeviceId(void);

RSCRASHREPORTER_EXTERN NSDictionary * RSCGetSystemInfo(void);

RSCRASHREPORTER_EXTERN NSTimeInterval RSCCrashSentryDeliveryTimeout;

NS_ASSUME_NONNULL_END
