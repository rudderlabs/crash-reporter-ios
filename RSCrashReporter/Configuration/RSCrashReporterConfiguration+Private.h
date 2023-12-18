//
//  RSCrashReporterConfiguration+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 26/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "RSCDefines.h"
#import "RSCrashReporterInternals.h"

@class RSCrashReporterNotifier;

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterConfiguration ()

#pragma mark Initializers

- (instancetype)initWithDictionaryRepresentation:(NSDictionary<NSString *, id> *)JSONObject NS_DESIGNATED_INITIALIZER;

#pragma mark Properties

@property (readonly, nonatomic) NSDictionary<NSString *, id> *dictionaryRepresentation;

@property (nonatomic) RSCFeatureFlagStore *featureFlagStore;

@property (copy, nonatomic) RSCrashReporterMetadata *metadata;

@property (readonly, nullable, nonatomic) NSURL *notifyURL;

@property (nonatomic) NSMutableSet *plugins;

@property (readonly, nonatomic) BOOL shouldSendReports;

@property (readonly, nonnull, nonatomic) NSURLSession *sessionOrDefault;

@property (readonly, nullable, nonatomic) NSURL *sessionURL;

@property (readwrite, retain, nonnull, nonatomic) RSCrashReporterUser *user;

#pragma mark Methods

+ (BOOL)isValidApiKey:(NSString *)apiKey;

- (BOOL)shouldDiscardErrorClass:(NSString *)errorClass;

- (BOOL)shouldRecordBreadcrumbType:(RSCBreadcrumbType)breadcrumbType;

/// Throws an NSInvalidArgumentException if the API key is empty or missing.
/// Logs a warning message if the API key is not in the expected format.
- (void)validate;

@end

@interface RSCrashReporterConfiguration (/* not objc_direct */) <NSCopying>
@end

NS_ASSUME_NONNULL_END
