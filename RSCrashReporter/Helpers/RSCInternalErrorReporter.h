//
//  RSCInternalErrorReporter.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 06/05/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"

@class RSCrashReporterEvent;

NS_ASSUME_NONNULL_BEGIN

/// Returns a concise desription of the error including its domain, code, and debug description or localizedDescription.
NSString *_Nullable RSCErrorDescription(NSError *_Nullable error);

// MARK: -

RSC_OBJC_DIRECT_MEMBERS
@interface RSCInternalErrorReporter : NSObject

@property (class, nullable, nonatomic) RSCInternalErrorReporter *sharedInstance;

/// Runs the block immediately if sharedInstance exists, otherwise runs the block once sharedInstance has been created.
+ (void)performBlock:(void (^)(RSCInternalErrorReporter *))block;

- (instancetype)initWithApiKey:(NSString *)apiKey endpoint:(NSURL *)endpoint NS_DESIGNATED_INITIALIZER;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

- (void)reportException:(NSException *)exception
            diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics
           groupingHash:(nullable NSString *)groupingHash;

- (void)reportRecrash:(NSDictionary *)recrashReport;

// Private

- (nullable RSCrashReporterEvent *)eventWithErrorClass:(NSString *)errorClass
                                       context:(nullable NSString *)context
                                       message:(nullable NSString *)message
                                   diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics;

- (nullable RSCrashReporterEvent *)eventWithException:(NSException *)exception
                                  diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics
                                 groupingHash:(nullable NSString *)groupingHash;

- (nullable RSCrashReporterEvent *)eventWithRecrashReport:(NSDictionary *)recrashReport;

- (nullable NSURLRequest *)requestForEvent:(RSCrashReporterEvent *)event error:(NSError * __autoreleasing *)errorPtr;

@end

@interface RSCInternalErrorReporter (/* not objc_direct */)

/// Reports an error to RSCrashReporter's internal bugsnag-cocoa project dashboard.
/// @param errorClass The class of error which occurred. This field is used to group the errors together so should not contain any contextual
/// information that would prevent correct grouping. This would ordinarily be the Exception name when dealing with an exception.
/// @param context The context to associate with this event. Errors are grouped by errorClass:context
/// @param message The error message associated with the error. Usually this will contain some information about this specific instance of the error
/// and is not used to group the errors.
/// @param diagnostics JSON compatible information to include in the `RSCrashReporterDiagnostics` metadata section.
- (void)reportErrorWithClass:(NSString *)errorClass
                     context:(nullable NSString *)context
                     message:(nullable NSString *)message
                 diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics;

@end

NS_ASSUME_NONNULL_END
