//
//  RSCFeatureFlagStore.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCFeatureFlagStore.h"

#import "RSCKeys.h"
#import "RSCrashReporterFeatureFlag.h"

void RSCFeatureFlagStoreAddFeatureFlag(RSCFeatureFlagStore *store, NSString *name, NSString *_Nullable variant) {
    [store addFeatureFlag:name withVariant:variant];
}

void RSCFeatureFlagStoreAddFeatureFlags(RSCFeatureFlagStore *store, NSArray<RSCrashReporterFeatureFlag *> *featureFlags) {
    [store addFeatureFlags:featureFlags];
}

void RSCFeatureFlagStoreClear(RSCFeatureFlagStore *store, NSString *_Nullable name) {
    [store clear:name];
}

NSArray<NSDictionary *> * RSCFeatureFlagStoreToJSON(RSCFeatureFlagStore *store) {
    return [store toJSON];
}

RSCFeatureFlagStore * RSCFeatureFlagStoreFromJSON(id json) {
    return [RSCFeatureFlagStore fromJSON:json];
}


/**
 * Stores feature flags as a dictionary containing the flag name as a key, with the
 * value being the index into an array containing the complete feature flag.
 *
 * Removals leave holes in the array, which gets rebuilt on clear once there are too many holes.
 *
 * This gives the access speed of a dictionary while keeping ordering intact.
 */
RSC_OBJC_DIRECT_MEMBERS
@interface RSCFeatureFlagStore ()

@property(nonatomic, readwrite) NSMutableArray *flags;
@property(nonatomic, readwrite) NSMutableDictionary *indices;

@end

static const int REBUILD_AT_HOLE_COUNT = 1000;

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCFeatureFlagStore

+ (nonnull RSCFeatureFlagStore *) fromJSON:(nonnull id)json {
    RSCFeatureFlagStore *store = [RSCFeatureFlagStore new];
    if ([json isKindOfClass:[NSArray class]]) {
        for (id item in json) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSString *featureFlag = item[RSCKeyFeatureFlag];
                if ([featureFlag isKindOfClass:[NSString class]]) {
                    id variant = item[RSCKeyVariant];
                    if (![variant isKindOfClass:[NSString class]]) {
                        variant = nil;
                    }
                    [store addFeatureFlag:featureFlag withVariant:variant];
                }
            }
        }
    }
    return store;
}

- (nonnull instancetype) init {
    if ((self = [super init]) != nil) {
        _flags = [NSMutableArray new];
        _indices = [NSMutableDictionary new];
    }
    return self;
}

static inline int getIndexFromDict(NSDictionary *dict, NSString *name) {
    NSNumber *boxedIndex = dict[name];
    if (boxedIndex == nil) {
        return -1;
    }
    return boxedIndex.intValue;
}

- (NSUInteger) count {
    return self.indices.count;
}

- (nonnull NSArray<RSCrashReporterFeatureFlag *> *) allFlags {
    NSMutableArray<RSCrashReporterFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:self.indices.count];
    for (RSCrashReporterFeatureFlag *flag in self.flags) {
        if ([flag isKindOfClass:[RSCrashReporterFeatureFlag class]]) {
            [flags addObject:flag];
        }
    }
    return flags;
}

- (void)rebuildIfTooManyHoles {
    int holeCount = (int)self.flags.count - (int)self.indices.count;
    if (holeCount < REBUILD_AT_HOLE_COUNT) {
        return;
    }

    NSMutableArray *newFlags = [NSMutableArray arrayWithCapacity:self.indices.count];
    NSMutableDictionary *newIndices = [NSMutableDictionary new];
    for (RSCrashReporterFeatureFlag *flag in self.flags) {
        if ([flag isKindOfClass:[RSCrashReporterFeatureFlag class]]) {
            [newFlags addObject:flag];
        }
    }

    for (NSUInteger i = 0; i < newFlags.count; i++) {
        RSCrashReporterFeatureFlag *flag = newFlags[i];
        newIndices[flag.name] = @(i);
    }
    self.flags = newFlags;
    self.indices = newIndices;
}

- (void) addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    RSCrashReporterFeatureFlag *flag = [RSCrashReporterFeatureFlag flagWithName:name variant:variant];

    int index = getIndexFromDict(self.indices, name);
    if (index >= 0) {
        self.flags[(unsigned)index] = flag;
    } else {
        index = (int)self.flags.count;
        [self.flags addObject:flag];
        self.indices[name] = @(index);
    }
}

- (void) addFeatureFlags:(nonnull NSArray<RSCrashReporterFeatureFlag *> *)featureFlags {
    for (RSCrashReporterFeatureFlag *flag in featureFlags) {
        [self addFeatureFlag:flag.name withVariant:flag.variant];
    }
}

- (void) clear:(nullable NSString *)name {
    if (name != nil) {
        int index = getIndexFromDict(self.indices, name);
        if (index >= 0) {
            self.flags[(unsigned)index] = [NSNull null];
            [self.indices removeObjectForKey:(id)name];
            [self rebuildIfTooManyHoles];
        }
    } else {
        [self.indices removeAllObjects];
        [self.flags removeAllObjects];
    }
}

- (nonnull NSArray<NSDictionary *> *) toJSON {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    for (RSCrashReporterFeatureFlag *flag in self.flags) {
        if ([flag isKindOfClass:[RSCrashReporterFeatureFlag class]]) {
            if (flag.variant) {
                [result addObject:@{RSCKeyFeatureFlag:flag.name, RSCKeyVariant:(NSString *_Nonnull)flag.variant}];
            } else {
                [result addObject:@{RSCKeyFeatureFlag:flag.name}];
            }
        }
    }
    return result;
}

- (id)copyWithZone:(NSZone *)zone {
    RSCFeatureFlagStore *store = [[RSCFeatureFlagStore allocWithZone:zone] init];
    store.flags = [self.flags mutableCopy];
    store.indices = [self.indices mutableCopy];
    return store;
}

@end
