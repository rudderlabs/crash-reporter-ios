//
//  RSCrashReporterError+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 23/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "RSCDefines.h"
#import "RSCrashReporterInternals.h"

NS_ASSUME_NONNULL_BEGIN

@class RSCrashReporterThread;

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterError ()

- (instancetype)initWithKSCrashReport:(NSDictionary *)event stacktrace:(NSArray<RSCrashReporterStackframe *> *)stacktrace;

/// The string representation of the RSCErrorType
@property (copy, nonatomic) NSString *typeString;

/// Parses the `__crash_info` message and updates the `errorClass` and `errorMessage` as appropriate.
- (void)updateWithCrashInfoMessage:(NSString *)crashInfoMessage;

- (NSDictionary *)toDictionary;

@end

NSString *RSCParseErrorClass(NSDictionary *error, NSString *errorType);

NSString * _Nullable RSCParseErrorMessage(NSDictionary *report, NSDictionary *error, NSString *errorType);

RSCErrorType RSCParseErrorType(NSString *errorType);

NSString *RSCSerializeErrorType(RSCErrorType errorType);

NS_ASSUME_NONNULL_END
