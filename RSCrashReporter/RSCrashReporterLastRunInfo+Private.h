//
//  RSCrashReporterLastRunInfo+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 10/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#include "RSCrashReporterLastRunInfo.h"

@interface RSCrashReporterLastRunInfo ()

- (instancetype)initWithConsecutiveLaunchCrashes:(NSUInteger)consecutiveLaunchCrashes
                                         crashed:(BOOL)crashed
                             crashedDuringLaunch:(BOOL)crashedDuringLaunch;

@end
