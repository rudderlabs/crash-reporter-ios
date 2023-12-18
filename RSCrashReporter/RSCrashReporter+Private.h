//
//  RSCrashReporter+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <RSCrashReporter/RSCrashReporter.h>

#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporter ()

#pragma mark Methods

+ (void)purge;

@end

NS_ASSUME_NONNULL_END
