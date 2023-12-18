//
//  RSCStorageMigratorV0V1.h
//  RSCrashReporter
//
//  Created by Karl Stenerud on 04.01.21.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCStorageMigratorV0V1 : NSObject

+ (BOOL) migrate;

@end

NS_ASSUME_NONNULL_END
