//
//  RSC_KSCrash.m
//
//  Created by Karl Stenerud on 2012-01-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RSC_KSCrash.h"

#import "RSCAppKit.h"
#import "RSCDefines.h"
#import "RSCUIKit.h"
#import "RSCWatchKit.h"
#import "RSC_KSCrashC.h"
#import "RSC_KSCrashIdentifier.h"

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define RSC_kCrashStateFilenameSuffix "-CrashState.json"

@implementation RSC_KSCrash

+ (RSC_KSCrash *)sharedInstance {
    static id sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rsc_kscrash_init();
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (RSC_KSCrashType)install:(RSC_KSCrashType)crashTypes directory:(NSString *)directory {
    rsc_kscrash_generate_report_initialize(directory.fileSystemRepresentation);
    NSString *nextCrashID = [NSUUID UUID].UUIDString;
    char *crashReportPath = rsc_kscrash_generate_report_path(nextCrashID.UTF8String, false);
    char *recrashReportPath = rsc_kscrash_generate_report_path(nextCrashID.UTF8String, true);
    NSString *stateFilePrefix = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"]
    /* Not all processes have an Info.plist */ ?: NSProcessInfo.processInfo.processName;
    NSString *stateFilePath = [directory stringByAppendingPathComponent:
                               [stateFilePrefix stringByAppendingString:@RSC_kCrashStateFilenameSuffix]];
    
    rsc_kscrash_setHandlingCrashTypes(crashTypes);
    
    RSC_KSCrashType installedCrashTypes = rsc_kscrash_install(
        crashReportPath, recrashReportPath,
        [stateFilePath UTF8String], [nextCrashID UTF8String]);
    
    free(crashReportPath);
    free(recrashReportPath);
    
    NSNotificationCenter *nCenter = [NSNotificationCenter defaultCenter];
#if TARGET_OS_OSX
    // MacOS "active" serves the same purpose as "foreground" in iOS
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:NSApplicationDidResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:NSApplicationDidBecomeActiveNotification
                  object:nil];
#elif TARGET_OS_WATCH
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:WKApplicationDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:WKApplicationWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:WKApplicationDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:WKApplicationWillEnterForegroundNotification
                  object:nil];
#else
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:UIApplicationDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:UIApplicationWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:UIApplicationDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:UIApplicationWillEnterForegroundNotification
                  object:nil];
#endif

    return installedCrashTypes;
}

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

- (void)applicationDidBecomeActive {
    rsc_kscrashstate_notifyAppInForeground(true);
}

- (void)applicationWillResignActive {
    rsc_kscrashstate_notifyAppInForeground(true);
}

- (void)applicationDidEnterBackground {
    rsc_kscrashstate_notifyAppInForeground(false);
}

- (void)applicationWillEnterForeground {
    rsc_kscrashstate_notifyAppInForeground(true);
}

@end

//! Project version number for RSC_KSCrashFramework.
//const double RSC_KSCrashFrameworkVersionNumber = 1.813;

//! Project version string for RSC_KSCrashFramework.
//const unsigned char RSC_KSCrashFrameworkVersionString[] = "1.8.13";
