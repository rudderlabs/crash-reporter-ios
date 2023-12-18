//
//  RSCrashReporterMetadata+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "RSCrashReporterInternals.h"

#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ RSCMetadataObserver)(RSCrashReporterMetadata *);

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterMetadata () <NSCopying>

#pragma mark Properties

@property (nullable, nonatomic) RSCMetadataObserver observer;

@end

NS_ASSUME_NONNULL_END
