//
//  TestSupport.m
//  RSCrashReporter
//
//  Created by Karl Stenerud on 25.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "TestSupport.h"

#import "RSC_KSCrashC.h"
#import "RSC_KSCrashState.h"
#import "RSCFileLocations.h"
#import "RSCRunContext.h"
#import "RSCUtils.h"
#import "RSCrashReporter+Private.h"


@implementation TestSupport

+ (void) purgePersistentData {
    dispatch_sync(RSCGetFileSystemQueue(), ^{
        NSString *dir = [[RSCFileLocations current].events stringByDeletingLastPathComponent];
        NSError *error = nil;
        if (![NSFileManager.defaultManager removeItemAtPath:dir error:&error] &&
            !([error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError)) {
            [NSException raise:NSInternalInconsistencyException format:@"Could not delete %@", dir];
        }
    });
    
    [RSCrashReporter purge];
    
    rsc_lastRunContext = NULL;
}

@end
