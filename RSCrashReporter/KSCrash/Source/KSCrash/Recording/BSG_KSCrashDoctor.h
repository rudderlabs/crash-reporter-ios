//
//  RSC_KSCrashDoctor.h
//  RSC_KSCrash
//
//  Created by Karl Stenerud on 2012-11-10.
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"

RSC_OBJC_DIRECT_MEMBERS
@interface RSC_KSCrashDoctor : NSObject

- (NSString *)diagnoseCrash:(NSDictionary *)crashReport;

@end
