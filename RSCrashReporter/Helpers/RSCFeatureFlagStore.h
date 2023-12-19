//
//  RSCFeatureFlagStore.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCrashReporterInternals.h"
#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

void RSCFeatureFlagStoreAddFeatureFlag(RSCFeatureFlagStore *store, NSString *name, NSString *_Nullable variant);

void RSCFeatureFlagStoreAddFeatureFlags(RSCFeatureFlagStore *store, NSArray<RSCrashReporterFeatureFlag *> *featureFlags);

void RSCFeatureFlagStoreClear(RSCFeatureFlagStore *store, NSString *_Nullable name);

NSArray<NSDictionary *> * RSCFeatureFlagStoreToJSON(RSCFeatureFlagStore *store);

RSCFeatureFlagStore * RSCFeatureFlagStoreFromJSON(id _Nullable json);


RSC_OBJC_DIRECT_MEMBERS
@interface RSCFeatureFlagStore ()

@property(nonatomic,nonnull,readonly) NSArray<RSCrashReporterFeatureFlag *> * allFlags;

+ (nonnull RSCFeatureFlagStore *) fromJSON:(nonnull id)json;

- (NSUInteger) count;

- (void) addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant;

- (void) addFeatureFlags:(nonnull NSArray<RSCrashReporterFeatureFlag *> *)featureFlags;

- (void) clear:(nullable NSString *)name;

- (nonnull NSArray<NSDictionary *> *) toJSON;

@end

NS_ASSUME_NONNULL_END
