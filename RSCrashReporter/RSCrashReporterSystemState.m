//
//  RSCrashReporterSystemState.m
//  RSCrashReporter
//
//  Created by Karl Stenerud on 21.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "RSCrashReporterSystemState.h"

#if TARGET_OS_OSX
#import "RSCAppKit.h"
#else
#import "RSCUIKit.h"
#endif

#import <RSCrashReporter/RSCrashReporter.h>

#import "RSCFileLocations.h"
#import "RSCJSONSerialization.h"
#import "RSCUtils.h"
#import "RSC_KSCrashState.h"
#import "RSC_KSSystemInfo.h"
#import "RSCrashReporterLogger.h"

#import <stdatomic.h>

static NSString * const ConsecutiveLaunchCrashesKey = @"consecutiveLaunchCrashes";
static NSString * const InternalKey = @"internal";

static NSDictionary * loadPreviousState(NSString *jsonPath) {
    NSError *error = nil;
    NSMutableDictionary *state = (NSMutableDictionary *)RSCJSONDictionaryFromFile(jsonPath, NSJSONReadingMutableContainers, &error);
    if(![state isKindOfClass:[NSMutableDictionary class]]) {
        if (!(error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError)) {
            rsc_log_err(@"Could not load system_state.json: %@", error);
        }
        return @{};
    }

    return state;
}

id blankIfNilRSC(id value) {
    if(value == nil || [value isKindOfClass:[NSNull class]]) {
        return @"";
    }
    return value;
}

static NSMutableDictionary * initCurrentState(RSCrashReporterConfiguration *config) {
    NSDictionary *systemInfo = [RSC_KSSystemInfo systemInfo];

    NSMutableDictionary *app = [NSMutableDictionary new];
    app[RSCKeyId] = blankIfNilRSC(systemInfo[@RSC_KSSystemField_BundleID]);
    app[RSCKeyName] = blankIfNilRSC(systemInfo[@RSC_KSSystemField_BundleName]);
    app[RSCKeyReleaseStage] = config.releaseStage;
    app[RSCKeyVersion] = blankIfNilRSC(systemInfo[@RSC_KSSystemField_BundleShortVersion]);
    app[RSCKeyBundleVersion] = blankIfNilRSC(systemInfo[@RSC_KSSystemField_BundleVersion]);
    app[RSCKeyMachoUUID] = systemInfo[@RSC_KSSystemField_AppUUID];
    app[@"binaryArch"] = systemInfo[@RSC_KSSystemField_BinaryArch];
#if TARGET_OS_TV
    app[RSCKeyType] = @"tvOS";
#elif TARGET_OS_IOS
    app[RSCKeyType] = @"iOS";
#elif TARGET_OS_OSX
    app[RSCKeyType] = @"macOS";
#elif TARGET_OS_WATCH
    app[RSCKeyType] = @"watchOS";
#endif

    NSMutableDictionary *device = [NSMutableDictionary new];
    device[@"id"] = systemInfo[@RSC_KSSystemField_DeviceAppHash];
    device[@"jailbroken"] = systemInfo[@RSC_KSSystemField_Jailbroken];
    device[@"osBuild"] = systemInfo[@RSC_KSSystemField_OSVersion];
    device[@"osVersion"] = systemInfo[@RSC_KSSystemField_SystemVersion];
    device[@"osName"] = systemInfo[@RSC_KSSystemField_SystemName];
    // Translated from 'iDeviceMaj,Min' into human-readable "iPhone X" description on the server
    device[@"model"] = systemInfo[@RSC_KSSystemField_Machine];
    device[@"modelNumber"] = systemInfo[@ RSC_KSSystemField_Model];
    device[@"wordSize"] = @(PLATFORM_WORD_SIZE);
    device[@"locale"] = [[NSLocale currentLocale] localeIdentifier];
    device[@"runtimeVersions"] = @{
        @"clangVersion": systemInfo[@RSC_KSSystemField_ClangVersion] ?: @"",
        @"osBuild": systemInfo[@RSC_KSSystemField_OSVersion] ?: @""
    };
#if TARGET_OS_SIMULATOR
    device[@"simulator"] = @YES;
#else
    device[@"simulator"] = @NO;
#endif
    device[@"totalMemory"] = systemInfo[@ RSC_KSSystemField_Memory][@ RSC_KSSystemField_Size];

    NSMutableDictionary *state = [NSMutableDictionary new];
    state[RSCKeyApp] = app;
    state[RSCKeyDevice] = device;

    return state;
}

static NSDictionary *copyDictionary(NSDictionary *launchState) {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (id key in launchState) {
        dictionary[key] = [launchState[key] copy];
    }
    return dictionary;
}

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterSystemState ()

@property(readwrite,atomic) NSDictionary *currentLaunchState;
@property(readwrite,nonatomic) NSDictionary *lastLaunchState;
@property(readonly,nonatomic) NSString *persistenceFilePath;

@end

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterSystemState

- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)config {
    if ((self = [super init])) {
        _persistenceFilePath = [RSCFileLocations current].systemState;
        _lastLaunchState = loadPreviousState(_persistenceFilePath);
        _currentLaunchState = initCurrentState(config);
        _consecutiveLaunchCrashes = [_lastLaunchState[InternalKey][ConsecutiveLaunchCrashesKey] unsignedIntegerValue];
        [self sync];
    }
    return self;
}

- (void)setCodeBundleID:(NSString*)codeBundleID {
    [self setValue:codeBundleID forAppKey:RSCKeyCodeBundleId];
}

- (void)setConsecutiveLaunchCrashes:(NSUInteger)consecutiveLaunchCrashes {
    [self setValue:@(_consecutiveLaunchCrashes = consecutiveLaunchCrashes) forKey:ConsecutiveLaunchCrashesKey inSection:InternalKey];
}

- (void)setValue:(id)value forAppKey:(NSString *)key {
    [self setValue:value forKey:key inSection:SYSTEMSTATE_KEY_APP];
}

- (void)setValue:(id)value forKey:(NSString *)key inSection:(NSString *)section {
    [self mutateLaunchState:^(NSMutableDictionary *state) {
        if (state[section]) {
            state[section][key] = value;
        } else {
            state[section] = [NSMutableDictionary dictionaryWithObjectsAndKeys:value, key, nil];
        }
    }];
}

- (void)mutateLaunchState:(nonnull void (^)(NSMutableDictionary *state))block {
    static _Atomic(BOOL) writePending;
    @synchronized (self) {
        NSMutableDictionary *mutableState = [NSMutableDictionary dictionary];
        for (NSString *section in self.currentLaunchState) {
            mutableState[section] = [self.currentLaunchState[section] mutableCopy];
        }
        block(mutableState);
        // User-facing state should never mutate from under them.
        self.currentLaunchState = copyDictionary(mutableState);
        
        BOOL expected = NO;
        if (!atomic_compare_exchange_strong(&writePending, &expected, YES)) {
            // _writePending was YES -- avoid an unnecesary dispatch_async()
            return;
        }
    }
    // Run on a BG thread so we don't monopolize the notification queue.
    dispatch_async(RSCGetFileSystemQueue(), ^(void){
        atomic_store(&writePending, NO);
        [self sync];
    });
}

- (void)sync {
    NSDictionary *state = self.currentLaunchState;
    NSError *error = nil;
    if (!RSCJSONWriteToFileAtomically(state, self.persistenceFilePath, &error)) {
        rsc_log_err(@"System state cannot be written as JSON: %@", error);
    }
}

- (void)purge {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if(![fm removeItemAtPath:self.persistenceFilePath error:&error]) {
        rsc_log_err(@"Could not remove persistence file: %@", error);
    }
    self.lastLaunchState = loadPreviousState(self.persistenceFilePath);
}

@end
