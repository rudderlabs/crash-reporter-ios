//
//  RSCStorageMigratorV0V1.m
//  RSCrashReporter
//
//  Created by Karl Stenerud on 04.01.21.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCStorageMigratorV0V1.h"

#import "RSCFileLocations.h"
#import "RSCrashReporterLogger.h"

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCStorageMigratorV0V1

static void RemoveItem(NSFileManager *fileManager, NSString *path) {
    NSError *error = nil;
    if (![fileManager removeItemAtPath:path error:&error] && error.code != NSFileNoSuchFileError) {
        rsc_log_err(@"%@", error);
    }
}

+ (BOOL) migrate {
    NSString *bundleName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    NSString *cachesDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    if (!cachesDir.length) {
        rsc_log_err(@"Could not migrate v0 data to v1.");
        return false;
    }
    RSCFileLocations *files = [RSCFileLocations v1];

    NSDictionary *mappings = @{
        @"bugsnag_handled_crash.txt": files.flagHandledCrash,
        @"bugsnag/config.json": files.configuration,
        @"bugsnag/metadata.json": files.metadata,
        @"bugsnag/state.json": files.state,
        @"bugsnag/state/system_state.json": files.systemState,
        @"bugsnag/breadcrumbs": files.breadcrumbs,
        [@"Sessions" stringByAppendingPathComponent:bundleName]: files.sessions,
        [@"KSCrashReports" stringByAppendingPathComponent:bundleName]: files.kscrashReports,
    };

    NSFileManager *fm = [[NSFileManager alloc] init];
    NSError *err = nil;
    bool success = true;

    for (NSString *key in mappings) {
        NSString *srcPath = [cachesDir stringByAppendingPathComponent:key];
        NSString *dstPath = mappings[key];
        if ([fm fileExistsAtPath:srcPath]) {
            RemoveItem(fm, dstPath);
            if(![fm moveItemAtPath:srcPath toPath:dstPath error:&err]) {
                rsc_log_err(@"Could not move %@ to %@: %@", srcPath, dstPath, err);
                success = false;
            }
        }
    }

    for(NSString *path in @[
        [cachesDir stringByAppendingPathComponent:@"rsc_kvstore"],
        [cachesDir stringByAppendingPathComponent:@"bugsnag"],
        [cachesDir stringByAppendingPathComponent:@"KSCrashReports"],
        [cachesDir stringByAppendingPathComponent:@"Sessions"],
                          ]) {
        if(![fm removeItemAtPath:path error:&err]) {
            if (!([err.domain isEqual:NSCocoaErrorDomain] && err.code == NSFileNoSuchFileError)) {
                rsc_log_err(@"Could not remove %@: %@", path, err);
            }
        }
    }

    NSString *root = [files.events stringByDeletingLastPathComponent];
    RemoveItem(fm, [root stringByAppendingPathComponent:@"kvstore"]);

    return success;
}

@end
