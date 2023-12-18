//
//  RSCrashReporterDeviceWithState.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import "RSCrashReporterDeviceWithState.h"

#import "RSCHardware.h"
#import "RSCRunContext.h"
#import "RSCUtils.h"
#import "RSC_KSCrashReportFields.h"
#import "RSC_KSSystemInfo.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporter.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterDevice+Private.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterSystemState.h"

NSMutableDictionary *RSCParseDeviceMetadata(NSDictionary *event) {
    NSMutableDictionary *device = [NSMutableDictionary new];
    NSDictionary *state = [event valueForKeyPath:@"user.state.deviceState"];
    [device addEntriesFromDictionary:state];
    device[@"timezone"] = [event valueForKeyPath:@"system." RSC_KSSystemField_TimeZone];
    device[@"macCatalystiOSVersion"] = [event valueForKeyPath:@"system." RSC_KSSystemField_iOSSupportVersion];

#if TARGET_OS_SIMULATOR
    device[@"simulator"] = @YES;
#else
    device[@"simulator"] = @NO;
#endif

    device[@"wordSize"] = @(PLATFORM_WORD_SIZE);
    return device;
}

NSDictionary * RSCDeviceMetadataFromRunContext(const struct RSCRunContext *context) {
    NSMutableDictionary *device = [NSMutableDictionary dictionary];
#if RSC_HAVE_BATTERY
    device[RSCKeyBatteryLevel] = @(context->batteryLevel);
    // Our intepretation of "charging" really means "plugged in"
    device[RSCKeyCharging] = RSCIsBatteryCharging(context->batteryState) ? @YES : @NO;
#endif
    if (@available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        device[RSCKeyThermalState] = RSCStringFromThermalState(context->thermalState);
    }
    return device;
}

@implementation RSCrashReporterDeviceWithState

+ (RSCrashReporterDeviceWithState *) deviceFromJson:(NSDictionary *)json {
    RSCrashReporterDeviceWithState *device = [RSCrashReporterDeviceWithState new];
    device.id = nil;
    device.freeMemory = json[@"freeMemory"];
    device.freeDisk = json[@"freeDisk"];
    device.locale = json[@"locale"];
    device.manufacturer = json[@"manufacturer"];
    device.model = json[@"model"];
    device.modelNumber = json[@"modelNumber"];
    device.orientation = json[@"orientation"];
    device.osName = json[@"osName"];
    device.osVersion = json[@"osVersion"];
    device.runtimeVersions = json[@"runtimeVersions"];
    device.totalMemory = json[@"totalMemory"];

    id jailbroken = json[@"jailbroken"];
    if (jailbroken) {
        device.jailbroken = [(NSNumber *) jailbroken boolValue];
    }

    id time = json[@"time"];
    if ([time isKindOfClass:[NSString class]]) {
        device.time = [RSC_RFC3339DateTool dateFromString:time];
    }
    return device;
}

+ (RSCrashReporterDeviceWithState *)deviceWithKSCrashReport:(NSDictionary *)event {
    RSCrashReporterDeviceWithState *device = [RSCrashReporterDeviceWithState new];
    [self populateFields:device dictionary:event];
    device.orientation = [event valueForKeyPath:@"user.state.deviceState.orientation"];
    device.freeMemory = [event valueForKeyPath:@"system." RSC_KSSystemField_Memory "." RSC_KSCrashField_Free];
    device.freeDisk = [event valueForKeyPath:@"system." RSC_KSSystemField_Disk "." RSC_KSCrashField_Free];

    NSString *val = [event valueForKeyPath:@"report.timestamp"];

    if (val != nil) {
        device.time = [RSC_RFC3339DateTool dateFromString:val];
    }

    NSDictionary *extraRuntimeInfo = [event valueForKeyPath:@"user.state.device.extraRuntimeInfo"];

    if (extraRuntimeInfo) {
        [device appendRuntimeInfo:extraRuntimeInfo];
    }

    return device;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [[super toDictionary] mutableCopy];
    dict[@"freeDisk"] = self.freeDisk;
    dict[@"freeMemory"] = self.freeMemory;
    dict[@"orientation"] = self.orientation;
    dict[@"time"] = self.time ? [RSC_RFC3339DateTool stringFromDate:self.time] : nil;
    return dict;
}

@end
