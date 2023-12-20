//
//  RSCrashReporterApp+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <RSCrashReporter/RSCrashReporterApp.h>

#import "RSCDefines.h"

@class RSCrashReporterConfiguration;

struct RSCRunContext;

NS_ASSUME_NONNULL_BEGIN

@interface RSCrashReporterApp ()

+ (RSCrashReporterApp *)appWithDictionary:(NSDictionary *)event config:(RSCrashReporterConfiguration *)config codeBundleId:(NSString *)codeBundleId;

+ (RSCrashReporterApp *)deserializeFromJson:(nullable NSDictionary *)json;

+ (void)populateFields:(RSCrashReporterApp *)app dictionary:(NSDictionary *)event config:(RSCrashReporterConfiguration *)config codeBundleId:(NSString *)codeBundleId;

- (void)setValuesFromConfiguration:(RSCrashReporterConfiguration *)configuration;

- (NSDictionary *)toDict;

@end

NSDictionary *RSCParseAppMetadata(NSDictionary *event);

NSDictionary *RSCAppMetadataFromRunContext(const struct RSCRunContext *context);

NS_ASSUME_NONNULL_END
