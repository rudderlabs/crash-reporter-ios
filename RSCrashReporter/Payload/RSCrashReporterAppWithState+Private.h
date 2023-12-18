//
//  RSCrashReporterAppWithState+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterInternals.h"

@class RSCrashReporterConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface RSCrashReporterAppWithState ()

+ (RSCrashReporterAppWithState *)appWithDictionary:(NSDictionary *)event config:(RSCrashReporterConfiguration *)config codeBundleId:(nullable NSString *)codeBundleId;

@end

NS_ASSUME_NONNULL_END
