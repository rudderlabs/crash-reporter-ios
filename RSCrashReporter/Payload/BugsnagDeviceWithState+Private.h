//
//  RSCrashReporterDeviceWithState+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import "RSCrashReporterInternals.h"

struct RSCRunContext;

NS_ASSUME_NONNULL_BEGIN

@interface RSCrashReporterDeviceWithState ()

#pragma mark Initializers

+ (instancetype)deviceFromJson:(NSDictionary *)json;

+ (instancetype)deviceWithKSCrashReport:(NSDictionary *)event;

#pragma mark Methods

- (void)appendRuntimeInfo:(NSDictionary *)info;

@end

NSMutableDictionary *RSCParseDeviceMetadata(NSDictionary *event);

NSDictionary * RSCDeviceMetadataFromRunContext(const struct RSCRunContext *context);

NS_ASSUME_NONNULL_END
