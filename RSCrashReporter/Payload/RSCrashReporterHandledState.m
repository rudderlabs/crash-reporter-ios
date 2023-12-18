//
//  RSCrashReporterHandledState.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 21/09/2017.
//  Copyright © 2017 RSCrashReporter. All rights reserved.
//

#import "RSCrashReporterHandledState.h"

#import "RSCDefines.h"
#import "RSCKeys.h"

RSCSeverity RSCParseSeverity(NSString *severity) {
    if ([severity isEqualToString:RSCKeyInfo])
        return RSCSeverityInfo;
    else if ([severity isEqualToString:RSCKeyWarning])
        return RSCSeverityWarning;
    return RSCSeverityError;
}

NSString *RSCFormatSeverity(RSCSeverity severity) {
    switch (severity) {
    case RSCSeverityError:
        return RSCKeyError;
    case RSCSeverityInfo:
        return RSCKeyInfo;
    case RSCSeverityWarning:
        return RSCKeyWarning;
    }
}

static NSString *const kUnhandled = @"unhandled";
static NSString *const kUnhandledOverridden = @"unhandledOverridden";
static NSString *const kSeverityReasonType = @"severityReasonType";
static NSString *const kOriginalSeverity = @"originalSeverity";
static NSString *const kCurrentSeverity = @"currentSeverity";
static NSString *const kAttrValue = @"attrValue";
static NSString *const kAttrKey = @"attrKey";

static NSString *const kAppHang = @"appHang";
static NSString *const kUnhandledException = @"unhandledException";
static NSString *const kSignal = @"signal";
static NSString *const kPromiseRejection = @"unhandledPromiseRejection";
static NSString *const kHandledError = @"handledError";
static NSString *const kLikelyOutOfMemory = @"outOfMemory";
static NSString *const kThermalKill = @"thermalKill";
static NSString *const kLogGenerated = @"log";
static NSString *const kHandledException = @"handledException";
static NSString *const kUserSpecifiedSeverity = @"userSpecifiedSeverity";
static NSString *const kUserCallbackSetSeverity = @"userCallbackSetSeverity";

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterHandledState

+ (instancetype)handledStateFromJson:(NSDictionary *)json {
    BOOL unhandled = [json[RSCKeyUnhandled] boolValue];
    NSDictionary *severityReason = json[RSCKeySeverityReason];
    BOOL unhandledOverridden = [severityReason[RSCKeyUnhandledOverridden] boolValue];
    RSCSeverity severity = RSCParseSeverity(json[RSCKeySeverity]);

    NSString *attrValue = nil;
    NSDictionary *attrs = severityReason[RSCKeyAttributes];

    if (attrs != nil && [attrs count] == 1) { // only 1 attrValue is ever present
        attrValue = [attrs allValues][0];
    }
    SeverityReasonType reason = [RSCrashReporterHandledState severityReasonFromString:severityReason[RSCKeyType]];
    return [[RSCrashReporterHandledState alloc] initWithSeverityReason:reason
                                                      severity:severity
                                                     unhandled:unhandled
                                           unhandledOverridden:unhandledOverridden
                                                     attrValue:attrValue];
}

+ (instancetype)handledStateWithSeverityReason:
    (SeverityReasonType)severityReason {
    return [self handledStateWithSeverityReason:severityReason
                                       severity:RSCSeverityWarning
                                      attrValue:nil];
}

+ (instancetype)handledStateWithSeverityReason:
                    (SeverityReasonType)severityReason
                                      severity:(RSCSeverity)severity
                                     attrValue:(NSString *)attrValue {
    BOOL unhandled = NO;
    BOOL unhandledOverridden = NO;

    switch (severityReason) {
    case PromiseRejection:
        severity = RSCSeverityError;
        unhandled = YES;
        break;
    case Signal:
        severity = RSCSeverityError;
        unhandled = YES;
        break;
    case HandledError:
        severity = RSCSeverityWarning;
        break;
    case HandledException:
        severity = RSCSeverityWarning;
        break;
    case LogMessage:
    case UserSpecifiedSeverity:
    case UserCallbackSetSeverity:
        break;
    case LikelyOutOfMemory:
    case ThermalKill:
    case UnhandledException:
        severity = RSCSeverityError;
        unhandled = YES;
        break;
    case AppHang:
        severity = RSCSeverityError;
        unhandled = NO;
        break;
    }

    return [[RSCrashReporterHandledState alloc] initWithSeverityReason:severityReason
                                                      severity:severity
                                                     unhandled:unhandled
                                           unhandledOverridden:unhandledOverridden
                                                     attrValue:attrValue];
}

- (instancetype)initWithSeverityReason:(SeverityReasonType)severityReason
                              severity:(RSCSeverity)severity
                             unhandled:(BOOL)unhandled
                   unhandledOverridden:(BOOL)unhandledOverridden
                             attrValue:(NSString *)attrValue {
    if ((self = [super init])) {
        _severityReasonType = severityReason;
        _currentSeverity = severity;
        _originalSeverity = severity;
        _unhandled = unhandled;
        _unhandledOverridden = unhandledOverridden;

        if (severityReason == Signal) {
            _attrValue = attrValue;
            _attrKey = @"signalType";
        } else if (severityReason == LogMessage) {
            _attrValue = attrValue;
            _attrKey = @"level";
        }
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _unhandled = [dict[kUnhandled] boolValue];
        _severityReasonType = [RSCrashReporterHandledState
            severityReasonFromString:dict[kSeverityReasonType]];
        _originalSeverity = RSCParseSeverity(dict[kOriginalSeverity]);
        _currentSeverity = RSCParseSeverity(dict[kCurrentSeverity]);
        _attrKey = dict[kAttrKey];
        _attrValue = dict[kAttrValue];
    }
    return self;
}

- (SeverityReasonType)calculateSeverityReasonType {
    return self.originalSeverity == self.currentSeverity ? self.severityReasonType
                                                 : UserCallbackSetSeverity;
}

+ (NSString *)stringFromSeverityReason:(SeverityReasonType)severityReason {
    switch (severityReason) {
    case Signal:
        return kSignal;
    case HandledError:
        return kHandledError;
    case HandledException:
        return kHandledException;
    case UserCallbackSetSeverity:
        return kUserCallbackSetSeverity;
    case PromiseRejection:
        return kPromiseRejection;
    case UserSpecifiedSeverity:
        return kUserSpecifiedSeverity;
    case LogMessage:
        return kLogGenerated;
    case UnhandledException:
        return kUnhandledException;
    case LikelyOutOfMemory:
        return kLikelyOutOfMemory;
    case ThermalKill:
        return kThermalKill;
    case AppHang:
        return kAppHang;
    }
}

+ (SeverityReasonType)severityReasonFromString:(NSString *)string {
    if ([kUnhandledException isEqualToString:string]) {
        return UnhandledException;
    } else if ([kSignal isEqualToString:string]) {
        return Signal;
    } else if ([kLogGenerated isEqualToString:string]) {
        return LogMessage;
    } else if ([kHandledError isEqualToString:string]) {
        return HandledError;
    } else if ([kHandledException isEqualToString:string]) {
        return HandledException;
    } else if ([kUserSpecifiedSeverity isEqualToString:string]) {
        return UserSpecifiedSeverity;
    } else if ([kUserCallbackSetSeverity isEqualToString:string]) {
        return UserCallbackSetSeverity;
    } else if ([kPromiseRejection isEqualToString:string]) {
        return PromiseRejection;
    } else if ([kLikelyOutOfMemory isEqualToString:string]) {
        return LikelyOutOfMemory;
    } else if ([kThermalKill isEqualToString:string]) {
        return ThermalKill;
    } else if ([kAppHang isEqualToString:string]) {
        return AppHang;
    } else {
        return UnhandledException;
    }
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[kUnhandled] = @(self.unhandled);
    if(self.unhandledOverridden) {
        dict[kUnhandledOverridden] = @(self.unhandledOverridden);
    }
    dict[kSeverityReasonType] =
        [RSCrashReporterHandledState stringFromSeverityReason:self.severityReasonType];
    dict[kOriginalSeverity] = RSCFormatSeverity(self.originalSeverity);
    dict[kCurrentSeverity] = RSCFormatSeverity(self.currentSeverity);
    dict[kAttrKey] = self.attrKey;
    dict[kAttrValue] = self.attrValue;
    return dict;
}

- (BOOL)originalUnhandledValue {
    return self.unhandledOverridden ? !self.unhandled : self.unhandled;
}

@end
