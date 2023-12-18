//
//  RSCrashReporterBreadcrumb+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import "RSCDefines.h"
#import "RSCrashReporterInternals.h"

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterBreadcrumb ()

- (BOOL)isValid;

/// String representation of `timestamp` used to avoid unnecessary date <--> string conversions
@property (copy, nullable, nonatomic) NSString *timestampString;

@end

NS_ASSUME_NONNULL_END
