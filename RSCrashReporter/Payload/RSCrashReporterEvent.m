//
//  RSCrashReporterEvent.m
//  RSCrashReporter
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import "RSCrashReporterEvent+Private.h"

#import "RSCDefines.h"
#import "RSCFeatureFlagStore.h"
#import "RSCJSONSerialization.h"
#import "RSCKeys.h"
#import "RSCSerialization.h"
#import "RSCUtils.h"
#import "RSC_KSCrashReportFields.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporter+Private.h"
#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterAppWithState+Private.h"
#import "RSCrashReporterBreadcrumb+Private.h"
#import "RSCrashReporterBreadcrumbs.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterDeviceWithState+Private.h"
#import "RSCrashReporterError+Private.h"
#import "RSCrashReporterHandledState.h"
#import "RSCrashReporterMetadata+Private.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterSession+Private.h"
#import "RSCrashReporterStackframe+Private.h"
#import "RSCrashReporterStacktrace.h"
#import "RSCrashReporterThread+Private.h"
#import "RSCrashReporterUser+Private.h"

static NSString * const RedactedMetadataValue = @"[REDACTED]";

id RSCLoadConfigValue(NSDictionary *report, NSString *valueName) {
    NSString *keypath = [NSString stringWithFormat:@"user.config.%@", valueName];
    NSString *fallbackKeypath = [NSString stringWithFormat:@"user.config.config.%@", valueName];

    return [report valueForKeyPath:keypath]
    ?: [report valueForKeyPath:fallbackKeypath]; // some custom values are nested
}

/**
 * Attempt to find a context (within which the event is being reported)
 * This can be found in user-set metadata of varying specificity or the global
 * configuration.  Returns nil if no context can be found.
 *
 * @param report A dictionary of report data
 * @returns A string context if found, or nil
 */
NSString *RSCParseContext(NSDictionary *report) {
    id context = [report valueForKeyPath:@"user.overrides.context"];
    if ([context isKindOfClass:[NSString class]]) {
        return context;
    }
    context = RSCLoadConfigValue(report, RSCKeyContext);
    if ([context isKindOfClass:[NSString class]]) {
        return context;
    }
    return nil;
}

NSString *RSCParseGroupingHash(NSDictionary *report) {
    id groupingHash = [report valueForKeyPath:@"user.overrides.groupingHash"];
    if (groupingHash)
        return groupingHash;
    return nil;
}

/** 
 * Find the breadcrumb cache for the event within the report object.
 *
 * By default, crumbs are present in the `user.state.crash` object, which is
 * the location of user data within crash and notify reports. However, this
 * location can be overridden in the case that a callback modifies breadcrumbs
 * or that breadcrumbs are persisted separately (such as in an out-of-memory
 * event).
 */
NSArray <RSCrashReporterBreadcrumb *> *RSCParseBreadcrumbs(NSDictionary *report) {
    // default to overwritten breadcrumbs from callback
    NSArray *cache = [report valueForKeyPath:@"user.overrides.breadcrumbs"]
        // then cached breadcrumbs from an OOM event
        ?: [report valueForKeyPath:@"user.state.oom.breadcrumbs"]
        // then cached breadcrumbs from a regular event
        // KSCrashReports from earlier versions of the notifier used this
        ?: [report valueForKeyPath:@"user.state.crash.breadcrumbs"]
        // breadcrumbs added to a KSCrashReport by BSSerializeDataCrashHandler
        ?: [report valueForKeyPath:@"user.breadcrumbs"];
    NSMutableArray *breadcrumbs = [NSMutableArray arrayWithCapacity:cache.count];
    for (NSDictionary *data in cache) {
        if (![data isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        RSCrashReporterBreadcrumb *crumb = [RSCrashReporterBreadcrumb breadcrumbFromDict:data];
        if (crumb) {
            [breadcrumbs addObject:crumb];
        }
    }
    return breadcrumbs;
}

NSString *RSCParseReleaseStage(NSDictionary *report) {
    return [report valueForKeyPath:@"user.overrides.releaseStage"]
               ?: RSCLoadConfigValue(report, @"releaseStage");
}

NSDictionary *RSCParseCustomException(NSDictionary *report,
                                      NSString *errorClass, NSString *message) {
    id frames =
        [report valueForKeyPath:@"user.overrides.customStacktraceFrames"];
    id type = [report valueForKeyPath:@"user.overrides.customStacktraceType"];
    if (type && frames) {
        return @{
            RSCKeyStacktrace : frames,
            RSCKeyType : type,
            RSCKeyErrorClass : errorClass,
            RSCKeyMessage : message
        };
    }

    return nil;
}

// MARK: -

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterEvent

/**
 * Constructs a new instance of RSCrashReporterEvent. This is the preferred constructor
 * and initialises all the mandatory fields. All internal constructors should
 * chain this constructor to ensure a consistent state. This constructor should
 * only assign parameters to fields, and should avoid any complex business logic.
 *
 * @param app the state of the app at the time of the error
 * @param device the state of the app at the time of the error
 * @param handledState whether the error was handled/unhandled, plus additional severity info
 * @param user the user at the time of the error
 * @param metadata the metadata at the time of the error
 * @param breadcrumbs the breadcrumbs at the time of the error
 * @param errors an array of errors representing a causal relationship
 * @param threads the threads at the time of the error, or empty if none
 * @param session the active session or nil if
 * @return a new instance of RSCrashReporterEvent.
 */
- (instancetype)initWithApp:(RSCrashReporterAppWithState *)app
                     device:(RSCrashReporterDeviceWithState *)device
               handledState:(RSCrashReporterHandledState *)handledState
                       user:(RSCrashReporterUser *)user
                   metadata:(RSCrashReporterMetadata *)metadata
                breadcrumbs:(NSArray<RSCrashReporterBreadcrumb *> *)breadcrumbs
                     errors:(NSArray<RSCrashReporterError *> *)errors
                    threads:(NSArray<RSCrashReporterThread *> *)threads
                    session:(RSCrashReporterSession *)session {
    if ((self = [super init])) {
        _app = app;
        _device = device;
        _handledState = handledState;
        // _user is nonnull but this method is not public so _Nonnull is unenforcable,  Guard explicitly.
        /*if (user != nil) {
            _user = user;
        }*/
        _metadata = metadata;
        _breadcrumbs = breadcrumbs;
        _errors = errors;
        _featureFlagStore = [[RSCFeatureFlagStore alloc] init];
        _threads = threads;
        _session = [session copy];
    }
    return self;
}

- (instancetype)initWithJson:(NSDictionary *)json {
    if ((self = [super init])) {
        _apiKey = RSCDeserializeString(json[RSCKeyApiKey]);

        _app = RSCDeserializeObject(json[RSCKeyApp], ^id _Nullable(NSDictionary * _Nonnull dict) {
            return [RSCrashReporterAppWithState appFromJson:dict];
        }) ?: [[RSCrashReporterAppWithState alloc] init];

        _breadcrumbs = RSCDeserializeArrayOfObjects(json[RSCKeyBreadcrumbs], ^id _Nullable(NSDictionary * _Nonnull dict) {
            return [RSCrashReporterBreadcrumb breadcrumbFromDict:dict];
        }) ?: @[];

        _context = RSCDeserializeString(json[RSCKeyContext]);

        _device = RSCDeserializeObject(json[RSCKeyDevice], ^id _Nullable(NSDictionary * _Nonnull dict) {
            return [RSCrashReporterDeviceWithState deviceFromJson:dict];
        }) ?: [[RSCrashReporterDeviceWithState alloc] init];

        _errors = RSCDeserializeArrayOfObjects(json[RSCKeyExceptions], ^id _Nullable(NSDictionary * _Nonnull dict) {
            return [RSCrashReporterError errorFromJson:dict];
        }) ?: @[];

        _featureFlagStore = RSCFeatureFlagStoreFromJSON(json[RSCKeyFeatureFlags]);

        _groupingHash = RSCDeserializeString(json[RSCKeyGroupingHash]);

        _handledState = [RSCrashReporterHandledState handledStateFromJson:json];

        _metadata = RSCDeserializeObject(json[RSCKeyMetadata], ^id _Nullable(NSDictionary * _Nonnull dict) {
            return [[RSCrashReporterMetadata alloc] initWithDictionary:dict];
        }) ?: [[RSCrashReporterMetadata alloc] init];

        _threads = RSCDeserializeArrayOfObjects(json[RSCKeyThreads], ^id _Nullable(NSDictionary * _Nonnull dict) {
            return [RSCrashReporterThread threadFromJson:dict];
        }) ?: @[];

        _usage = RSCDeserializeDict(json[RSCKeyUsage]);

        /*_user = RSCDeserializeObject(json[RSCKeyUser], ^id _Nullable(NSDictionary * _Nonnull dict) {
            return [[RSCrashReporterUser alloc] initWithDictionary:dict];
        }) ?: [[RSCrashReporterUser alloc] init];

        _session = RSCSessionFromEventJson(json[RSCKeySession], _app, _device, _user);*/
    }
    return self;
}

/**
 * Creates a RSCrashReporterEvent from a JSON crash report generated by KSCrash. A KSCrash
 * report can come in 3 variants, which needs to be deserialized separately:
 *
 * 1. An unhandled error which immediately terminated the process
 * 2. A handled error which did not terminate the process
 * 3. An OOM, which has more limited information than the previous two errors
 *
 *  @param event a KSCrash report
 *
 *  @return a RSCrashReporterEvent containing the parsed information
 */
- (instancetype)initWithKSReport:(NSDictionary *)event {
    if (event.count == 0) {
        return nil; // report is empty
    }
    if ([[event valueForKeyPath:@"user.state.didOOM"] boolValue]) {
        return nil; // OOMs are no longer stored as KSCrashReports
    } else if ([event valueForKeyPath:@"user.event"] != nil) {
        return [self initWithUserData:event];
    } else {
        return [self initWithKSCrashReport:event];
    }
}

/**
 * Creates a RSCrashReporterEvent from unhandled error JSON. Unhandled errors use
 * the JSON schema supplied by the KSCrash report rather than the RSCrashReporter
 * Error API schema, which is more complex to parse.
 *
 * @param event a KSCrash report
 *
 * @return a RSCrashReporterEvent containing the parsed information
 */
- (instancetype)initWithKSCrashReport:(NSDictionary *)event {
    NSMutableDictionary *error = [[event valueForKeyPath:@"crash.error"] mutableCopy];
    NSString *errorType = error[RSCKeyType];

    // Always assume that a report coming from KSCrash is by default an unhandled error.
    BOOL isUnhandled = YES;
    BOOL isUnhandledOverridden = NO;
    BOOL hasBecomeHandled = [event valueForKeyPath:@"user.unhandled"] != nil &&
            [[event valueForKeyPath:@"user.unhandled"] boolValue] == false;
    if (hasBecomeHandled) {
        const int handledCountAdjust = 1;
        isUnhandled = NO;
        isUnhandledOverridden = YES;
        NSMutableDictionary *user = [event[RSCKeyUser] mutableCopy];
        user[@"unhandled"] = @(isUnhandled);
        user[@"unhandledOverridden"] = @(isUnhandledOverridden);
        user[@"unhandledCount"] = @([user[@"unhandledCount"] intValue] - handledCountAdjust);
        user[@"handledCount"] = @([user[@"handledCount"] intValue] + handledCountAdjust);
        NSMutableDictionary *eventCopy = [event mutableCopy];
        eventCopy[RSCKeyUser] = user;
        event = eventCopy;
    }

    id userMetadata = [event valueForKeyPath:@"user.metaData"];
    RSCrashReporterMetadata *metadata;

    if ([userMetadata isKindOfClass:[NSDictionary class]]) {
        metadata = [[RSCrashReporterMetadata alloc] initWithDictionary:userMetadata];
    } else {
        metadata = [RSCrashReporterMetadata new];
    }

    [metadata addMetadata:error toSection:RSCKeyError];

    // Device information that isn't part of `event.device`
    NSMutableDictionary *deviceMetadata = RSCParseDeviceMetadata(event);
#if RSC_HAVE_BATTERY
    deviceMetadata[RSCKeyBatteryLevel] = [event valueForKeyPath:@"user.batteryLevel"];
    deviceMetadata[RSCKeyCharging] = [event valueForKeyPath:@"user.charging"];
#endif
    if (@available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        NSNumber *thermalState = [event valueForKeyPath:@"user.thermalState"];
        if ([thermalState isKindOfClass:[NSNumber class]]) {
            deviceMetadata[RSCKeyThermalState] = RSCStringFromThermalState(thermalState.longValue);
        }
    }
    [metadata addMetadata:deviceMetadata toSection:RSCKeyDevice];

    [metadata addMetadata:RSCParseAppMetadata(event) toSection:RSCKeyApp];

    NSDictionary *recordedState = [event valueForKeyPath:@"user.handledState"];

    NSUInteger depth;
    if (recordedState) { // only makes sense to use serialised value for handled exceptions
        depth = [[event valueForKeyPath:@"user.depth"] unsignedIntegerValue];
    } else {
        depth = 0;
    }

    // generate threads/error info
    NSArray *binaryImages = event[@"binary_images"];
    NSArray *threadDict = [event valueForKeyPath:@"crash.threads"];
    NSArray<RSCrashReporterThread *> *threads = [RSCrashReporterThread threadsFromArray:threadDict binaryImages:binaryImages];

    RSCrashReporterThread *errorReportingThread = nil;
    for (RSCrashReporterThread *thread in threads) {
        if (thread.errorReportingThread) {
            errorReportingThread = thread;
            break;
        }
    }

    NSArray<RSCrashReporterError *> *errors = @[[[RSCrashReporterError alloc] initWithKSCrashReport:event stacktrace:errorReportingThread.stacktrace ?: @[]]];

    // KSCrash captures only the offending thread when sendThreads = RSCThreadSendPolicyNever.
    // The RSCrashReporterEvent should not contain threads in this case, only the stacktrace.
    if (threads.count == 1) {
        threads = @[];
    }

    if (errorReportingThread.crashInfoMessage) {
        [errors[0] updateWithCrashInfoMessage:(NSString * _Nonnull)errorReportingThread.crashInfoMessage];
        [metadata addMetadata:errorReportingThread.crashInfoMessage withKey:@"crashInfo" toSection:@"error"];
    }
    
    RSCrashReporterHandledState *handledState;
    if (recordedState) {
        handledState = [[RSCrashReporterHandledState alloc] initWithDictionary:recordedState];
    } else { // the event was (probably) unhandled.
        BOOL isSignal = [RSCKeySignal isEqualToString:errorType];
        SeverityReasonType severityReason = isSignal ? Signal : UnhandledException;
        handledState = [RSCrashReporterHandledState
                handledStateWithSeverityReason:severityReason
                                      severity:RSCSeverityError
                                     attrValue:errors[0].errorClass];
        handledState.unhandled = isUnhandled;
        handledState.unhandledOverridden = isUnhandledOverridden;
    }

    [[self parseOnCrashData:event] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if ([key isKindOfClass:[NSString class]] &&
            [obj isKindOfClass:[NSDictionary class]]) {
            [metadata addMetadata:obj toSection:key];
        }
    }];

    NSString *deviceAppHash = [event valueForKeyPath:@"system.device_app_hash"];
    RSCrashReporterDeviceWithState *device = [RSCrashReporterDeviceWithState deviceWithKSCrashReport:event];
#if TARGET_OS_IOS
    NSNumber *orientation = [event valueForKeyPath:@"user.orientation"];
    if ([orientation isKindOfClass:[NSNumber class]]) {
        device.orientation = RSCStringFromDeviceOrientation(orientation.longValue);
    }
#endif

    RSCrashReporterUser *user = [self parseUser:event deviceAppHash:deviceAppHash deviceId:device.id];

    NSDictionary *configDict = [event valueForKeyPath:@"user.config"];
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithDictionaryRepresentation:
                                    [configDict isKindOfClass:[NSDictionary class]] ? configDict : @{}];

    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState appWithDictionary:event config:config codeBundleId:self.codeBundleId];

    RSCrashReporterSession *session = RSCSessionFromCrashReport(event, app, device, user);

    RSCrashReporterEvent *obj = [self initWithApp:app
                                   device:device
                             handledState:handledState
                                     user:user
                                 metadata:metadata
                              breadcrumbs:RSCParseBreadcrumbs(event)
                                   errors:errors
                                  threads:threads
                                  session:session];
    obj.context = RSCParseContext(event);
    obj.groupingHash = RSCParseGroupingHash(event);
    obj.enabledReleaseStages = RSCLoadConfigValue(event, RSCKeyEnabledReleaseStages);
    obj.releaseStage = RSCParseReleaseStage(event);
    obj.deviceAppHash = deviceAppHash;
    obj.featureFlagStore = RSCFeatureFlagStoreFromJSON([event valueForKeyPath:@"user.state.client.featureFlags"]);
    obj.context = [event valueForKeyPath:@"user.state.client.context"];
    obj.customException = RSCParseCustomException(event, [errors[0].errorClass copy], [errors[0].errorMessage copy]);
    obj.depth = depth;
    obj.usage = [event valueForKeyPath:@"user._usage"];
    return obj;
}

/**
 * Creates a RSCrashReporterEvent from handled error JSON. Handled errors use
 * the RSCrashReporter Error API JSON schema, with the exception that they are
 * wrapped in a KSCrash JSON object.
 *
 * @param crashReport a KSCrash report
 *
 * @return a RSCrashReporterEvent containing the parsed information
 */
- (instancetype)initWithUserData:(NSDictionary *)crashReport {
    NSDictionary *json = RSCDeserializeDict([crashReport valueForKeyPath:@"user.event"]);
    if (!json || !(self = [self initWithJson:json])) {
        return nil;
    }
    _apiKey = RSCDeserializeString(json[RSCKeyApiKey]);
    _context = RSCDeserializeString(json[RSCKeyContext]);
    _featureFlagStore = [[RSCFeatureFlagStore alloc] init];
    _groupingHash = RSCDeserializeString(json[RSCKeyGroupingHash]);

    if (_errors.count) {
        RSCrashReporterError *error = _errors[0];
        _customException = RSCParseCustomException(crashReport, error.errorClass, error.errorMessage);
    }
    return self;
}

- (NSMutableDictionary *)parseOnCrashData:(NSDictionary *)report {
    NSMutableDictionary *userAtCrash = [report[RSCKeyUser] mutableCopy];
    // avoid adding internal information to user-defined metadata
    NSArray *keysToRemove = @[
            @RSC_KSCrashField_Overrides,
            @RSC_KSCrashField_HandledState,
            @RSC_KSCrashField_Metadata,
            @RSC_KSCrashField_State,
            @RSC_KSCrashField_Config,
            @RSC_KSCrashField_DiscardDepth,
            @"batteryLevel",
            @"breadcrumbs",
            @"charging",
            @"handledCount",
            @"id",
            @"isLaunching",
            @"orientation",
            @"startedAt",
            @"thermalState",
            @"unhandledCount",
    ];
    [userAtCrash removeObjectsForKeys:keysToRemove];

    for (NSString *key in [userAtCrash allKeys]) {
        if ([key hasPrefix:@"_"]) {
            [userAtCrash removeObjectForKey:key];
            continue;
        }
        if (![userAtCrash[key] isKindOfClass:[NSDictionary class]]) {
            rsc_log_debug(@"Removing value added in onCrashHandler for key %@ as it is not a dictionary value", key);
            [userAtCrash removeObjectForKey:key];
        }
    }
    return userAtCrash;
}

// MARK: - apiKey

@synthesize apiKey = _apiKey;

- (NSString *)apiKey {
    return _apiKey;
}

- (void)setApiKey:(NSString *)apiKey {
    if ([RSCrashReporterConfiguration isValidApiKey:apiKey]) {
        _apiKey = apiKey;
    }

    // A malformed apiKey should not cause an error: the fallback global value
    // in RSCrashReporterConfiguration will do to get the event reported.
    else {
        rsc_log_warn(@"Attempted to set an invalid Event API key.");
    }
}

- (BOOL)shouldBeSent {
    return [self.enabledReleaseStages containsObject:self.releaseStage ?: @""] ||
           (self.enabledReleaseStages.count == 0);
}

- (NSArray<NSDictionary *> *)serializeBreadcrumbsWithRedactedKeys:(NSSet *)redactedKeys {
    return RSCArrayMap(self.breadcrumbs, ^NSDictionary * (RSCrashReporterBreadcrumb *breadcrumb) {
        NSMutableDictionary *dictionary = [[breadcrumb objectValue] mutableCopy];
        NSDictionary *metadata = dictionary[RSCKeyMetadata];
        NSMutableDictionary *redactedMetadata = [NSMutableDictionary dictionary];
        for (NSString *key in metadata) {
            redactedMetadata[key] = [self redactedMetadataValue:metadata[key] forKey:key redactedKeys:redactedKeys];
        }
        dictionary[RSCKeyMetadata] = redactedMetadata;
        return dictionary;
    });
}

- (void)attachCustomStacktrace:(NSArray *)frames withType:(NSString *)type {
    RSCrashReporterError *error = self.errors.firstObject;
    error.stacktrace = [RSCrashReporterStacktrace stacktraceFromJson:frames].trace;
    error.typeString = type;
}

- (RSCSeverity)severity {
    return self.handledState.currentSeverity;
}

- (void)setSeverity:(RSCSeverity)severity {
    self.handledState.currentSeverity = severity;
}

// =============================================================================
// MARK: - User
// =============================================================================

/**
 *  Set user metadata
 *
 *  @param userId ID of the user
 *  @param name   Name of the user
 *  @param email  Email address of the user
 */
- (void)setUser:(NSString *_Nullable)userId
      withEmail:(NSString *_Nullable)email
        andName:(NSString *_Nullable)name {
    // self.user = [[RSCrashReporterUser alloc] initWithId:userId name:name emailAddress:email];
}

/**
 * Read the user from a persisted KSCrash report
 * @param event the KSCrash report
 * @return the user, or nil if not available
 */
- (RSCrashReporterUser *)parseUser:(NSDictionary *)event
             deviceAppHash:(NSString *)deviceAppHash
                  deviceId:(NSString *)deviceId {
    NSMutableDictionary *user = [[event valueForKeyPath:@"user.state"][RSCKeyUser] mutableCopy];
    
    if (user == nil) { // fallback to legacy location
        user = [[event valueForKeyPath:@"user.metaData"][RSCKeyUser] mutableCopy];
    }
    if (user == nil) { // fallback to empty dict
        user = [NSMutableDictionary new];
    }

    if (!user[RSCKeyId] && deviceId) { // if device id is null, don't set user id to default
        user[RSCKeyId] = deviceAppHash;
    }
    return [[RSCrashReporterUser alloc] initWithDictionary:user];
}

- (void)notifyUnhandledOverridden {
    self.handledState.unhandledOverridden = YES;
}

- (NSDictionary *)toJsonWithRedactedKeys:(NSSet *)redactedKeys {
    NSMutableDictionary *event = [NSMutableDictionary dictionary];

    event[RSCKeyExceptions] = ({
        NSMutableArray *array = [NSMutableArray array];
        [self.errors enumerateObjectsUsingBlock:^(RSCrashReporterError *error, NSUInteger idx, __unused BOOL *stop) {
            if (self.customException != nil && idx == 0) {
                [array addObject:(NSDictionary * _Nonnull)self.customException];
            } else {
                [array addObject:[error toDictionary]];
            }
        }];
        [NSArray arrayWithArray:array];
    });
    
    event[RSCKeyThreads] = [RSCrashReporterThread serializeThreads:self.threads];
    event[RSCKeySeverity] = RSCFormatSeverity(self.severity);
    event[RSCKeyBreadcrumbs] = [self serializeBreadcrumbsWithRedactedKeys:redactedKeys];

    NSMutableDictionary *metadata = [[[self metadata] toDictionary] mutableCopy];
    @try {
        [self redactKeys:redactedKeys inMetadata:metadata];
        event[RSCKeyMetadata] = metadata;
    } @catch (NSException *exception) {
        rsc_log_err(@"An exception was thrown while sanitising metadata: %@", exception);
    }

    event[RSCKeyApiKey] = self.apiKey;
    event[RSCKeyDevice] = [self.device toDictionary];
    event[RSCKeyApp] = [self.app toDict];

    event[RSCKeyContext] = [self context];
    event[RSCKeyFeatureFlags] = RSCFeatureFlagStoreToJSON(self.featureFlagStore);
    event[RSCKeyGroupingHash] = self.groupingHash;

    event[RSCKeyUnhandled] = @(self.handledState.unhandled);

    // serialize handled/unhandled into payload
    NSMutableDictionary *severityReason = [NSMutableDictionary new];
    if (self.handledState.unhandledOverridden) {
        severityReason[RSCKeyUnhandledOverridden] = @(self.handledState.unhandledOverridden);
    }
    NSString *reasonType = [RSCrashReporterHandledState
        stringFromSeverityReason:self.handledState.calculateSeverityReasonType];
    severityReason[RSCKeyType] = reasonType;

    if (self.handledState.attrKey && self.handledState.attrValue) {
        severityReason[RSCKeyAttributes] =
            @{self.handledState.attrKey : self.handledState.attrValue};
    }

    event[RSCKeySeverityReason] = severityReason;

    //  Inserted into `context` property
    [metadata removeObjectForKey:RSCKeyContext];

    // add user
//    event[RSCKeyUser] = [self.user toJson];

    event[RSCKeySession] = self.session ? RSCSessionToEventJson((RSCrashReporterSession *_Nonnull)self.session) : nil;

    event[RSCKeyUsage] = self.usage;

    return event;
}

- (void)redactKeys:(NSSet *)redactedKeys inMetadata:(NSMutableDictionary *)metadata {
    for (NSString *sectionKey in [metadata allKeys]) {
        if ([metadata[sectionKey] isKindOfClass:[NSDictionary class]]) {
            metadata[sectionKey] = [metadata[sectionKey] mutableCopy];
        } else {
            NSString *message = [NSString stringWithFormat:@"Expected an NSDictionary but got %@ %@",
                                 NSStringFromClass([(id _Nonnull)metadata[sectionKey] class]), metadata[sectionKey]];
            rsc_log_err(@"%@", message);
            // Leave an indication of the error in the payload for diagnosis
            metadata[sectionKey] = [@{@"bugsnag.error": message} mutableCopy];
        }
        NSMutableDictionary *section = metadata[sectionKey];

        if (section != nil) { // redact sensitive metadata values
            for (NSString *objKey in [section allKeys]) {
                section[objKey] = [self redactedMetadataValue:section[objKey] forKey:objKey redactedKeys:redactedKeys];
            }
        }
    }
}

- (id)redactedMetadataValue:(id)value forKey:(NSString *)key redactedKeys:(NSSet *)redactedKeys {
    if ([self redactedKeys:redactedKeys matches:key]) {
        return RedactedMetadataValue;
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *nestedDict = [(NSDictionary *)value mutableCopy];
        for (NSString *nestedKey in [nestedDict allKeys]) {
            nestedDict[nestedKey] = [self redactedMetadataValue:nestedDict[nestedKey] forKey:nestedKey redactedKeys:redactedKeys];
        }
        return nestedDict;
    } else {
        return value;
    }
}

- (BOOL)redactedKeys:(NSSet *)redactedKeys matches:(NSString *)key {
    for (id obj in redactedKeys) {
        if ([obj isKindOfClass:[NSString class]]) {
            if ([[key lowercaseString] isEqualToString:[obj lowercaseString]]) {
                return true;
            }
        } else if ([obj isKindOfClass:[NSRegularExpression class]]) {
            NSRegularExpression *regex = obj;
            NSRange range = NSMakeRange(0, [key length]);
            if ([[regex matchesInString:key options:0 range:range] count] > 0) {
                return true;
            }
        }
    }
    return false;
}

- (void)symbolicateIfNeeded {
    for (RSCrashReporterError *error in self.errors) {
        for (RSCrashReporterStackframe *stackframe in error.stacktrace) {
            [stackframe symbolicateIfNeeded];
        }
    }
    for (RSCrashReporterThread *thread in self.threads) {
        for (RSCrashReporterStackframe *stackframe in thread.stacktrace) {
            [stackframe symbolicateIfNeeded];
        }
    }
}

- (void)trimBreadcrumbs:(const NSUInteger)bytesToRemove {
    NSMutableArray *breadcrumbs = [self.breadcrumbs mutableCopy];
    RSCrashReporterBreadcrumb *lastRemovedBreadcrumb = nil;
    NSUInteger bytesRemoved = 0, count = 0;
    
    while (bytesRemoved < bytesToRemove && breadcrumbs.count) {
        lastRemovedBreadcrumb = [breadcrumbs firstObject];
        [breadcrumbs removeObjectAtIndex:0];
        
        NSDictionary *dict = [lastRemovedBreadcrumb objectValue];
        NSData *data = RSCJSONDataFromDictionary(dict, NULL);
        bytesRemoved += data.length;
        count++;
    }
    
    if (lastRemovedBreadcrumb) {
        lastRemovedBreadcrumb.message = count < 2 ? @"Removed to reduce payload size" :
        [NSString stringWithFormat:@"Removed, along with %lu older breadcrumb%s, to reduce payload size",
         (unsigned long)(count - 1), count == 2 ? "" : "s"];
        lastRemovedBreadcrumb.metadata = @{};
        [breadcrumbs insertObject:lastRemovedBreadcrumb atIndex:0];
    }
    
    self.breadcrumbs = breadcrumbs;
    
    NSDictionary *usage = self.usage;
    if (usage) {
        self.usage = RSCDictMerge(@{
            @"system": @{
                @"breadcrumbBytesRemoved": @(bytesRemoved),
                @"breadcrumbsRemoved": @(count)}
        }, usage);
    }
}

- (void)truncateStrings:(NSUInteger)maxLength {
    RSCTruncateContext context = {
        .maxLength = maxLength
    };
    
    if (self.context) {
        self.context = RSCTruncatePossibleString(&context, self.context);
    }
    
    for (RSCrashReporterError *error in self.errors) {
        error.errorClass = RSCTruncatePossibleString(&context, error.errorClass);
        error.errorMessage = RSCTruncatePossibleString(&context, error.errorMessage);
    }
    
    for (RSCrashReporterBreadcrumb *breadcrumb in self.breadcrumbs) {
        breadcrumb.message = RSCTruncateString(&context, breadcrumb.message);
        breadcrumb.metadata = RSCTruncateStrings(&context, breadcrumb.metadata);
    }
    
    RSCrashReporterMetadata *metadata = self.metadata; 
    if (metadata) {
        self.metadata = [[RSCrashReporterMetadata alloc] initWithDictionary:
                         RSCTruncateStrings(&context, metadata.dictionary)];
    }
    
    NSDictionary *usage = self.usage;
    if (usage) {
        self.usage = RSCDictMerge(@{
            @"system": @{
                @"stringCharsTruncated": @(context.length),
                @"stringsTruncated": @(context.strings)}
        }, usage);
    }
}

- (BOOL)unhandled {
    return self.handledState.unhandled;
}

- (void)setUnhandled:(BOOL)unhandled {
    self.handledState.unhandled = unhandled;
}

// MARK: - <RSCrashReporterFeatureFlagStore>

- (NSArray<RSCrashReporterFeatureFlag *> *)featureFlags {
    return self.featureFlagStore.allFlags;
}

- (void)addFeatureFlagWithName:(NSString *)name variant:(nullable NSString *)variant {
    RSCFeatureFlagStoreAddFeatureFlag(self.featureFlagStore, name, variant);
}

- (void)addFeatureFlagWithName:(NSString *)name {
    RSCFeatureFlagStoreAddFeatureFlag(self.featureFlagStore, name, nil);
}

- (void)addFeatureFlags:(NSArray<RSCrashReporterFeatureFlag *> *)featureFlags {
    RSCFeatureFlagStoreAddFeatureFlags(self.featureFlagStore, featureFlags);
}

- (void)clearFeatureFlagWithName:(NSString *)name {
    RSCFeatureFlagStoreClear(self.featureFlagStore, name);
}

- (void)clearFeatureFlags {
    RSCFeatureFlagStoreClear(self.featureFlagStore, nil);
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

#pragma mark -

- (NSArray<NSString *> *)stacktraceTypes {
    NSMutableSet *stacktraceTypes = [NSMutableSet set];
    
    // The error in self.errors is not always the error that will be sent; this is the case when used in React Native.
    // Using [self toJson] to ensure this uses the same logic of reading from self.customException instead.
    NSDictionary *json = [self toJsonWithRedactedKeys:nil];
    NSArray *exceptions = json[RSCKeyExceptions];
    for (NSDictionary *exception in exceptions) {
        RSCrashReporterError *error = [RSCrashReporterError errorFromJson:exception];
        
        [stacktraceTypes addObject:RSCSerializeErrorType(error.type)];
        
        for (RSCrashReporterStackframe *stackframe in error.stacktrace) {
            RSCSetAddIfNonnull(stacktraceTypes, stackframe.type);
        }
    }
    
    for (RSCrashReporterThread *thread in self.threads) {
        [stacktraceTypes addObject:RSCSerializeThreadType(thread.type)];
        for (RSCrashReporterStackframe *stackframe in thread.stacktrace) {
            RSCSetAddIfNonnull(stacktraceTypes, stackframe.type);
        }
    }
    
    return stacktraceTypes.allObjects;
}

@end
