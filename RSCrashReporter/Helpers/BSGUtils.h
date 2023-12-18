//
//  RSCUtils.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 18/06/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"
#import "RSCUIKit.h"

__BEGIN_DECLS

NS_ASSUME_NONNULL_BEGIN

/// Returns a heap allocated null-terminated C string with the contents of `data`, or NULL if `data` is nil or empty.
char *_Nullable RSCCStringWithData(NSData *_Nullable data);

/// Changes the NSFileProtectionKey attribute of the specified file or directory from NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen.
/// Has no effect if the specified file or directory does not have NSFileProtectionComplete.
///
/// Files with NSFileProtectionComplete cannot be read from or written to while the device is locked or booting.
///
/// Files with NSFileProtectionCompleteUnlessOpen can be created while the device is locked, but once closed, cannot be opened again until the device is unlocked.
BOOL RSCDisableNSFileProtectionComplete(NSString *path);

dispatch_queue_t RSCGetFileSystemQueue(void);

#if TARGET_OS_IOS
NSString *_Nullable RSCStringFromDeviceOrientation(UIDeviceOrientation orientation);
#endif

API_AVAILABLE(ios(11.0), tvos(11.0))
NSString *_Nullable RSCStringFromThermalState(NSProcessInfoThermalState thermalState);

static inline NSString * _Nullable RSCStringFromClass(Class _Nullable cls) {
    return cls ? NSStringFromClass((Class _Nonnull)cls) : nil;
}

NS_ASSUME_NONNULL_END

__END_DECLS
