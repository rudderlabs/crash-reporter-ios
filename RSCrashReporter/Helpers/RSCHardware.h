//
//  RSCHardware.h
//  RSCrashReporter
//
//  Created by Karl Stenerud on 26.05.22.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#ifndef RSCHardware_h
#define RSCHardware_h

#import <Foundation/Foundation.h>

#import "RSCDefines.h"
#import "RSCUIKit.h"
#import "RSCWatchKit.h"

#pragma mark Device

#if TARGET_OS_IOS
static inline UIDevice *RSCGetDevice(void) {
    return [UIDEVICE currentDevice];
}
#elif TARGET_OS_WATCH
static inline WKInterfaceDevice *RSCGetDevice(void) {
    return [WKInterfaceDevice currentDevice];
}
#endif

#pragma mark Battery

#if RSC_HAVE_BATTERY

static inline BOOL RSCIsBatteryStateKnown(long battery_state) {
#if TARGET_OS_IOS
    const long state_unknown = UIDeviceBatteryStateUnknown;
#elif TARGET_OS_WATCH
    const long state_unknown = WKInterfaceDeviceBatteryStateUnknown;
#endif
    return battery_state != state_unknown;
}

static inline BOOL RSCIsBatteryCharging(long battery_state) {
#if TARGET_OS_IOS
    const long state_charging = UIDeviceBatteryStateCharging;
#elif TARGET_OS_WATCH
    const long state_charging = WKInterfaceDeviceBatteryStateCharging;
#endif
    return battery_state >= state_charging;
}

#endif // RSC_HAVE_BATTERY

#endif /* RSCHardware_h */
