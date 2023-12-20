//
//  RSCrashReporterLastRunInfo.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 10/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCrashReporterLastRunInfo+Private.h"

@implementation RSCrashReporterLastRunInfo

- (instancetype)initWithConsecutiveLaunchCrashes:(NSUInteger)consecutiveLaunchCrashes
                                         crashed:(BOOL)crashed
                             crashedDuringLaunch:(BOOL)crashedDuringLaunch {
    if ((self = [super init])) {
        _consecutiveLaunchCrashes = consecutiveLaunchCrashes;
        _crashed = crashed;
        _crashedDuringLaunch = crashedDuringLaunch;
    }
    return self;
}

@end
