//
//  RSCrashReporterBreadcrumb.m
//
//  Created by Delisa Mason on 9/16/15.
//
//  Copyright (c) 2015 RSCrashReporter, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
#import "RSC_RFC3339DateTool.h"

#import "RSCKeys.h"
#import "RSCrashReporterBreadcrumb+Private.h"
#import "RSCrashReporterBreadcrumbs.h"
#import "RSCrashReporterCollections.h"

typedef void (^RSCBreadcrumbConfiguration)(RSCrashReporterBreadcrumb *_Nonnull);

NSString *RSCBreadcrumbTypeValue(RSCBreadcrumbType type) {
    switch (type) {
    case RSCBreadcrumbTypeLog:
        return @"log";
    case RSCBreadcrumbTypeUser:
        return @"user";
    case RSCBreadcrumbTypeError:
        return RSCKeyError;
    case RSCBreadcrumbTypeState:
        return @"state";
    case RSCBreadcrumbTypeManual:
        return @"manual";
    case RSCBreadcrumbTypeProcess:
        return @"process";
    case RSCBreadcrumbTypeRequest:
        return @"request";
    case RSCBreadcrumbTypeNavigation:
        return @"navigation";
    }
}

RSCBreadcrumbType RSCBreadcrumbTypeFromString(NSString *value) {
    if ([value isEqual:@"log"]) {
        return RSCBreadcrumbTypeLog;
    } else if ([value isEqual:@"user"]) {
        return RSCBreadcrumbTypeUser;
    } else if ([value isEqual:@"error"]) {
        return RSCBreadcrumbTypeError;
    } else if ([value isEqual:@"state"]) {
        return RSCBreadcrumbTypeState;
    } else if ([value isEqual:@"process"]) {
        return RSCBreadcrumbTypeProcess;
    } else if ([value isEqual:@"request"]) {
        return RSCBreadcrumbTypeRequest;
    } else if ([value isEqual:@"navigation"]) {
        return RSCBreadcrumbTypeNavigation;
    } else {
        return RSCBreadcrumbTypeManual;
    }
}


@interface RSCrashReporterBreadcrumb ()

@property (readwrite, nullable, nonatomic) NSDate *timestamp;

@end


RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterBreadcrumb

- (instancetype)init {
    if ((self = [super init])) {
        _timestamp = [NSDate date];
        _type = RSCBreadcrumbTypeManual;
        _metadata = @{};
    }
    return self;
}

- (BOOL)isValid {
    return self.message.length > 0 && ([RSC_RFC3339DateTool isLikelyDateString:self.timestampString] || self.timestamp);
}

- (NSDictionary *)objectValue {
    NSString *timestamp = self.timestampString ?: [RSC_RFC3339DateTool stringFromDate:self.timestamp];
    if (timestamp && self.message.length > 0) {
        NSMutableDictionary *metadata = [NSMutableDictionary new];
        for (NSString *key in self.metadata) {
            metadata[[key copy]] = [self.metadata[key] copy];
        }
        return @{
            // Note: The RSCrashReporter Error Reporting API specifies that the breadcrumb "message"
            // field should be delivered in as a "name" field.  This comment notes that variance.
            RSCKeyName : [self.message copy],
            RSCKeyTimestamp : timestamp,
            RSCKeyType : RSCBreadcrumbTypeValue(self.type),
            RSCKeyMetadata : metadata
        };
    }
    return nil;
}

// The timestamp is lazily computed from the timestampString to avoid unnecessary
// calls to -dateFromString: (which is expensive) when loading breadcrumbs from disk.

- (NSDate *)timestamp {
    if (!_timestamp) {
        _timestamp = [RSC_RFC3339DateTool dateFromString:self.timestampString];
    }
    return _timestamp;
}

@synthesize timestampString = _timestampString;

- (void)setTimestampString:(NSString *)timestampString {
    _timestampString = [timestampString copy];
    self.timestamp = nil;
}

+ (instancetype)breadcrumbFromDict:(NSDictionary *)dict {
    NSDictionary *metadata = RSCDeserializeDict(dict[RSCKeyMetadata] ?: dict[@"metadata"] /* react-native uses lowercase key */);
    NSString *message = RSCDeserializeString(dict[RSCKeyMessage] ?: dict[RSCKeyName] /* Accept legacy 'name' value */);
    NSString *timestamp = RSCDeserializeString(dict[RSCKeyTimestamp]); 
    NSString *type = RSCDeserializeString(dict[RSCKeyType]);
    if (timestamp && type && message) {
        RSCrashReporterBreadcrumb *crumb = [RSCrashReporterBreadcrumb new];
        crumb.message = message;
        crumb.metadata = metadata ?: @{};
        crumb.timestampString = timestamp;
        crumb.type = RSCBreadcrumbTypeFromString(type);
        return [crumb isValid] ? crumb : nil;
    }
    return nil;
}

@end
