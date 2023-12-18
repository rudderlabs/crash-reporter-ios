//
//  RSCrashReporterFeatureFlag.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCrashReporterFeatureFlag.h"

@implementation RSCrashReporterFeatureFlag

+ (instancetype)flagWithName:(NSString *)name {
    return [[RSCrashReporterFeatureFlag alloc] initWithName:name variant:nil];
}

+ (instancetype)flagWithName:(NSString *)name variant:(nullable NSString *)variant {
    return [[RSCrashReporterFeatureFlag alloc] initWithName:name variant:variant];
}

- (instancetype)initWithName:(NSString *)name variant:(nullable NSString *)variant {
    if ((self = [super init])) {
        _name = [name copy];
        _variant = [variant copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }

    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[RSCrashReporterFeatureFlag class]]) {
        return NO;
    }

    RSCrashReporterFeatureFlag *obj = (RSCrashReporterFeatureFlag *)object;

    // Ignore the variant when checking for equality. We only care if the name matches
    // when checking for duplicates.
    return [obj.name isEqualToString:self.name];
}

@end
