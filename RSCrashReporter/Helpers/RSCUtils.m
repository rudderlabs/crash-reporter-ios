//
//  RSCUtils.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 18/06/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCUtils.h"

#import "RSCrashReporterLogger.h"

char *_Nullable RSCCStringWithData(NSData *_Nullable data) {
    char *buffer;
    if (data.length && (buffer = calloc(1, data.length + 1))) {
        [data getBytes:buffer length:data.length];
        return buffer;
    }
    return NULL;
}

BOOL RSCDisableNSFileProtectionComplete(NSString *path) {
    // Using NSFileProtection* causes run-time link errors on older versions of macOS.
    // NSURLFileProtectionKey is unavailable in macOS SDKs prior to 11.0
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSURL *url = [NSURL fileURLWithPath:path];
        
        NSURLFileProtectionType protection = nil;
        [url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil];
        
        if (protection != NSURLFileProtectionComplete) {
            return YES;
        }
        
        NSError *error = nil;
        if (![url setResourceValue:NSURLFileProtectionCompleteUnlessOpen
                            forKey:NSURLFileProtectionKey error:&error]) {
            rsc_log_warn(@"RSCDisableFileProtection: %@", error);
            return NO;
        }
        rsc_log_debug(@"Set NSFileProtectionCompleteUnlessOpen for %@", path);
    }
#else
    (void)(path);
#endif
    return YES;
}

dispatch_queue_t RSCGetFileSystemQueue(void) {
    static dispatch_once_t onceToken;
    static dispatch_queue_t queue;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.bugsnag.filesystem", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

#if TARGET_OS_IOS

NSString *_Nullable RSCStringFromDeviceOrientation(UIDeviceOrientation orientation) {
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown: return @"portraitupsidedown";
        case UIDeviceOrientationPortrait:           return @"portrait";
        case UIDeviceOrientationLandscapeRight:     return @"landscaperight";
        case UIDeviceOrientationLandscapeLeft:      return @"landscapeleft";
        case UIDeviceOrientationFaceUp:             return @"faceup";
        case UIDeviceOrientationFaceDown:           return @"facedown";
        case UIDeviceOrientationUnknown:            break;
    }
    return nil;
}

#endif

NSString *_Nullable RSCStringFromThermalState(NSProcessInfoThermalState thermalState) {
    switch (thermalState) {
        case NSProcessInfoThermalStateNominal:  return @"nominal";
        case NSProcessInfoThermalStateFair:     return @"fair";
        case NSProcessInfoThermalStateSerious:  return @"serious";
        case NSProcessInfoThermalStateCritical: return @"critical";
    }
    return nil;
}
