//
//  RSCrashReporterError.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterError+Private.h"

#import "RSCKeys.h"
#import "RSC_KSCrashDoctor.h"
#import "RSC_KSCrashReportFields.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterStackframe+Private.h"
#import "RSCrashReporterStacktrace.h"
#import "RSCrashReporterThread+Private.h"


typedef NSString * RSCErrorTypeString NS_TYPED_ENUM;

static RSCErrorTypeString const RSCErrorTypeStringCocoa = @"cocoa";
static RSCErrorTypeString const RSCErrorTypeStringC = @"c";
static RSCErrorTypeString const RSCErrorTypeStringReactNativeJs = @"reactnativejs";
static RSCErrorTypeString const RSCErrorTypeStringCSharp = @"csharp";


NSString *_Nonnull RSCSerializeErrorType(RSCErrorType errorType) {
    switch (errorType) {
        case RSCErrorTypeCocoa:
            return RSCErrorTypeStringCocoa;
        case RSCErrorTypeC:
            return RSCErrorTypeStringC;
        case RSCErrorTypeReactNativeJs:
            return RSCErrorTypeStringReactNativeJs;
        case RSCErrorTypeCSharp:
            return RSCErrorTypeStringCSharp;
    }
}

RSCErrorType RSCParseErrorType(NSString *errorType) {
    if ([RSCErrorTypeStringCocoa isEqualToString:errorType]) {
        return RSCErrorTypeCocoa;
    } else if ([RSCErrorTypeStringC isEqualToString:errorType]) {
        return RSCErrorTypeC;
    } else if ([RSCErrorTypeStringReactNativeJs isEqualToString:errorType]) {
        return RSCErrorTypeReactNativeJs;
    } else if ([RSCErrorTypeStringCSharp isEqualToString:errorType]) {
        return RSCErrorTypeCSharp;
    } else {
        return RSCErrorTypeCocoa;
    }
}


NSString *_Nonnull RSCParseErrorClass(NSDictionary *error, NSString *errorType) {
    NSString *errorClass;

    if ([errorType isEqualToString:RSCKeyCppException]) {
        errorClass = error[RSCKeyCppException][RSCKeyName];
    } else if ([errorType isEqualToString:RSCKeyMach]) {
        errorClass = error[RSCKeyMach][RSCKeyExceptionName];
    } else if ([errorType isEqualToString:RSCKeySignal]) {
        errorClass = error[RSCKeySignal][RSCKeyName];
    } else if ([errorType isEqualToString:@"nsexception"]) {
        errorClass = error[@"nsexception"][RSCKeyName];
    } else if ([errorType isEqualToString:RSCKeyUser]) {
        errorClass = error[@"user_reported"][RSCKeyName];
    }

    if (!errorClass) { // use a default value
        errorClass = @"Exception";
    }
    return errorClass;
}

NSString *RSCParseErrorMessage(NSDictionary *report, NSDictionary *error, NSString *errorType) {
    NSString *reason = error[@ RSC_KSCrashField_Reason];
    NSString *diagnosis = nil;
    if ([errorType isEqualToString:@ RSC_KSCrashExcType_Mach] || !reason) {
        diagnosis = [[RSC_KSCrashDoctor new] diagnoseCrash:report];
    }
    return diagnosis ?: reason ?: @"";
}

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterError

@dynamic type;

- (instancetype)initWithKSCrashReport:(NSDictionary *)event stacktrace:(NSArray<RSCrashReporterStackframe *> *)stacktrace {
    if ((self = [super init])) {
        NSDictionary *error = [event valueForKeyPath:@"crash.error"];
        NSString *errorType = error[RSCKeyType];
        _errorClass = RSCParseErrorClass(error, errorType);
        _errorMessage = RSCParseErrorMessage(event, error, errorType);
        _typeString = RSCSerializeErrorType(RSCErrorTypeCocoa);

        if (![[event valueForKeyPath:@"user.state.didOOM"] boolValue]) {
            _stacktrace = stacktrace;
        }
    }
    return self;
}

- (instancetype)initWithErrorClass:(NSString *)errorClass
                      errorMessage:(NSString *)errorMessage
                         errorType:(RSCErrorType)errorType
                        stacktrace:(NSArray<RSCrashReporterStackframe *> *)stacktrace {
    if ((self = [super init])) {
        _errorClass = errorClass;
        _errorMessage = errorMessage;
        _typeString = RSCSerializeErrorType(errorType);
        _stacktrace = stacktrace ?: @[];
    }
    return self;
}

+ (RSCrashReporterError *)errorFromJson:(NSDictionary *)json {
    RSCrashReporterError *error = [[RSCrashReporterError alloc] init];
    error.errorClass = RSCDeserializeString(json[RSCKeyErrorClass]);
    error.errorMessage = RSCDeserializeString(json[RSCKeyMessage]);
    error.stacktrace = RSCDeserializeArrayOfObjects(json[RSCKeyStacktrace], ^id _Nullable(NSDictionary * _Nonnull dict) {
        return [RSCrashReporterStackframe frameFromJson:dict];
    }) ?: @[];
    error.typeString = RSCDeserializeString(json[RSCKeyType]) ?: RSCErrorTypeStringCocoa;
    return error;
}

- (RSCErrorType)type {
    return RSCParseErrorType(self.typeString);
}

- (void)setType:(RSCErrorType)type {
    self.typeString = RSCSerializeErrorType(type);
}

- (void)updateWithCrashInfoMessage:(NSString *)crashInfoMessage {
    NSArray<NSString *> *patterns = @[
        // From Swift 2.2:
        //
        // https://github.com/apple/swift/blob/swift-2.2-RELEASE/stdlib/public/stubs/Assert.cpp#L24-L39
        @"^(assertion failed|fatal error|precondition failed): ((.+): )?file .+, line \\d+\n$",
        // https://github.com/apple/swift/blob/swift-2.2-RELEASE/stdlib/public/stubs/Assert.cpp#L41-L55
        @"^(assertion failed|fatal error|precondition failed): ((.+))?\n$",
        
        // From Swift 4.1: https://github.com/apple/swift/commit/d03a575279cf5c523779ef68f8d7903f09ba901e
        //
        // https://github.com/apple/swift/blob/swift-4.1-RELEASE/stdlib/public/stubs/Assert.cpp#L75-L95
        @"^(Assertion failed|Fatal error|Precondition failed): ((.+): )?file .+, line \\d+\n$",
        // https://github.com/apple/swift/blob/swift-4.1-RELEASE/stdlib/public/stubs/Assert.cpp#L97-L112
        // https://github.com/apple/swift/blob/swift-5.4-RELEASE/stdlib/public/stubs/Assert.cpp#L65-L80
        @"^(Assertion failed|Fatal error|Precondition failed): ((.+))?\n$",
        
        // From Swift 5.4: https://github.com/apple/swift/commit/1a051719e3b1b7c37a856684dd037d482fef8e59
        //
        // https://github.com/apple/swift/blob/swift-5.4-RELEASE/stdlib/public/stubs/Assert.cpp#L43-L63
        @"^.+:\\d+: (Assertion failed|Fatal error|Precondition failed)(: (.+))?\n$",
    ];
    
    for (NSString *pattern in patterns) {
        NSArray<NSTextCheckingResult *> *matches = nil;
        @try {
            NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
            matches = [regex matchesInString:crashInfoMessage options:0 range:NSMakeRange(0, crashInfoMessage.length)];
        } @catch (NSException *exception) {
            rsc_log_err(@"Exception thrown while parsing crash info message: %@", exception);
        }
        if (matches.count != 1 || matches[0].numberOfRanges != 4) {
            continue;
        }
        NSRange errorClassRange = [matches[0] rangeAtIndex:1];
        if (errorClassRange.location != NSNotFound) {
            self.errorClass = [crashInfoMessage substringWithRange:errorClassRange];
        }
        NSRange errorMessageRange = [matches[0] rangeAtIndex:3];
        if (errorMessageRange.location != NSNotFound) {
            self.errorMessage = [crashInfoMessage substringWithRange:errorMessageRange];
        }
        return; //!OCLint
    }
    
    if (!self.errorMessage.length) {
        // It's better to fall back to the raw string than have an empty errorMessage.
        self.errorMessage = crashInfoMessage;
    }
}

- (NSDictionary *)findErrorReportingThread:(NSDictionary *)event {
    NSArray *threads = [event valueForKeyPath:@"crash.threads"];

    for (NSDictionary *thread in threads) {
        if ([thread[@"crashed"] boolValue]) {
            return thread;
        }
    }
    return nil;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[RSCKeyErrorClass] = self.errorClass;
    dict[RSCKeyMessage] = self.errorMessage;
    dict[RSCKeyType] = self.typeString;

    NSMutableArray *frames = [NSMutableArray new];
    for (RSCrashReporterStackframe *frame in self.stacktrace) {
        [frames addObject:[frame toDictionary]];
    }

    dict[RSCKeyStacktrace] = frames;
    return dict;
}

@end
