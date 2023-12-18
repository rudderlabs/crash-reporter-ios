//
//  RSCrashReporterHandledState.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 21/09/2017.
//  Copyright © 2017 RSCrashReporter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterEvent.h>

typedef NS_ENUM(NSUInteger, SeverityReasonType) {
    UnhandledException,
    Signal,
    HandledError,
    HandledException,
    UserSpecifiedSeverity,
    UserCallbackSetSeverity,
    PromiseRejection,
    LogMessage,
    LikelyOutOfMemory,
    AppHang,
    ThermalKill,
};

/**
 *  Convert a string to a severity value
 *
 *  @param severity Intended severity value, such as info, warning, or error
 *
 *  @return converted severity level or RSCSeverityError if no conversion is
 * found
 */
RSCRASHREPORTER_EXTERN RSCSeverity RSCParseSeverity(NSString *severity);

/**
 *  Serialize a severity for JSON payloads
 *
 *  @param severity a severity
 *
 *  @return the equivalent string value
 */
NSString *RSCFormatSeverity(RSCSeverity severity);

RSCRASHREPORTER_EXTERN
@interface RSCrashReporterHandledState : NSObject

@property(nonatomic) BOOL unhandled;
@property(nonatomic) BOOL unhandledOverridden;
@property(nonatomic, readonly) BOOL originalUnhandledValue;
@property(nonatomic, readonly) SeverityReasonType severityReasonType;
@property(nonatomic, readonly) RSCSeverity originalSeverity;
@property(nonatomic) RSCSeverity currentSeverity;
@property(nonatomic, readonly) SeverityReasonType calculateSeverityReasonType;
@property(nonatomic, readonly, strong) NSString *attrValue;
@property(nonatomic, readonly, strong) NSString *attrKey;

+ (NSString *)stringFromSeverityReason:(SeverityReasonType)severityReason;
+ (SeverityReasonType)severityReasonFromString:(NSString *)string;

+ (instancetype)handledStateWithSeverityReason:
    (SeverityReasonType)severityReason;

+ (instancetype)handledStateFromJson:(NSDictionary *)json;

+ (instancetype)handledStateWithSeverityReason:
                    (SeverityReasonType)severityReason
                                      severity:(RSCSeverity)severity
                                     attrValue:(NSString *)attrValue;

- (instancetype)initWithSeverityReason:(SeverityReasonType)severityReason
                              severity:(RSCSeverity)severity
                             unhandled:(BOOL)unhandled
                   unhandledOverridden:(BOOL)unhandledOverridden
                             attrValue:(NSString *)attrValue;

- (NSDictionary *)toJson;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end
