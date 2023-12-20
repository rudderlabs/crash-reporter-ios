//
//  RSC_KSSystemInfo.h
//
//  Created by Karl Stenerud on 2012-02-05.
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

#import <RSCrashReporter/RSCrashReporterDefines.h>
#import <Foundation/Foundation.h>

#import "RSCDefines.h"

#define RSC_KSSystemField_AppUUID "app_uuid"
#define RSC_KSSystemField_BinaryArch "binary_arch"
#define RSC_KSSystemField_BundleID "CFBundleIdentifier"
#define RSC_KSSystemField_BundleName "CFBundleName"
#define RSC_KSSystemField_BundleExecutable "CFBundleExecutable"
#define RSC_KSSystemField_BundleShortVersion "CFBundleShortVersionString"
#define RSC_KSSystemField_BundleVersion "CFBundleVersion"
#define RSC_KSSystemField_CPUArch "cpu_arch"
#define RSC_KSSystemField_DeviceAppHash "device_app_hash"
#define RSC_KSSystemField_Disk "disk"
#define RSC_KSSystemField_Jailbroken "jailbroken"
#define RSC_KSSystemField_Machine "machine"
#define RSC_KSSystemField_Memory "memory"
#define RSC_KSSystemField_Model "model"
#define RSC_KSSystemField_OSVersion "os_version"
#define RSC_KSSystemField_Size "size"
#define RSC_KSSystemField_SystemName "system_name"
#define RSC_KSSystemField_SystemVersion "system_version"
#define RSC_KSSystemField_ClangVersion "clang_version"
#define RSC_KSSystemField_TimeZone "time_zone"
#define RSC_KSSystemField_Translated "proc_translated"
#define RSC_KSSystemField_iOSSupportVersion "iOSSupportVersion"

/**
 * Provides system information useful for a crash report.
 */
RSC_OBJC_DIRECT_MEMBERS
@interface RSC_KSSystemInfo : NSObject

/** Get the system info.
 *
 * @return The system info.
 */
+ (NSDictionary *)systemInfo;

/** Get this application's UUID.
 *
 * @return The UUID.
 */
+ (NSString *)appUUID;

/**
 * The build version of the OS
 */
+ (NSString *)osBuildVersion;

/**
 * Whether the current main bundle is an iOS app extension
 */
+ (BOOL)isRunningInAppExtension;

/** Generate a 20 byte SHA1 hash that remains unique across a single device and
 * application. This is slightly different from the Apple crash report key,
 * which is unique to the device, regardless of the application.
 *
 * @return The stringified hex representation of the hash for this device + app.
 */
+ (NSString *)deviceAndAppHash;

@end
