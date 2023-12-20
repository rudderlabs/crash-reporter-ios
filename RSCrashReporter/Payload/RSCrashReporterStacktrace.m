//
//  RSCrashReporterStacktrace.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 06/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterStacktrace.h"

#import "RSCKeys.h"
#import "RSCrashReporterStackframe+Private.h"

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterStacktrace

+ (instancetype)stacktraceFromJson:(NSArray<NSDictionary *> *)json {
    RSCrashReporterStacktrace *trace = [RSCrashReporterStacktrace new];
    NSMutableArray *data = [NSMutableArray new];

    if (json != nil) {
        for (NSDictionary *dict in json) {
            RSCrashReporterStackframe *frame = [RSCrashReporterStackframe frameFromJson:dict];

            if (frame != nil) {
                [data addObject:frame];
            }
        }
    }
    trace.trace = data;
    return trace;
}

- (instancetype)initWithTrace:(NSArray<NSDictionary *> *)trace
                 binaryImages:(NSArray<NSDictionary *> *)binaryImages {
    if ((self = [super init])) {
        _trace = [NSMutableArray new];

        for (NSDictionary *obj in trace) {
            RSCrashReporterStackframe *frame = [RSCrashReporterStackframe frameFromDict:obj withImages:binaryImages];

            if (frame != nil && [self.trace count] < 200) {
                [self.trace addObject:frame];
            }
        }
    }
    return self;
}

@end
