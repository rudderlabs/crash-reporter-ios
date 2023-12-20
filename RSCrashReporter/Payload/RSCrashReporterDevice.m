//
//  RSCrashReporterDevice.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterDevice.h"

#import "RSC_KSCrashReportFields.h"
#import "RSC_KSSystemInfo.h"
#import "RSCrashReporterConfiguration.h"
#import "RSCrashReporterCollections.h"

@implementation RSCrashReporterDevice

+ (RSCrashReporterDevice *)deserializeFromJson:(NSDictionary *)json {
    RSCrashReporterDevice *device = [RSCrashReporterDevice new];
    if (json != nil) {
        device.jailbroken = [json[@"jailbroken"] boolValue];
        device.id = nil; //json[@"id"];
        device.locale = json[@"locale"];
        device.manufacturer = json[@"manufacturer"];
        device.model = json[@"model"];
        device.modelNumber = json[@"modelNumber"];
        device.osName = json[@"osName"];
        device.osVersion = json[@"osVersion"];
        device.runtimeVersions = json[@"runtimeVersions"];
        device.totalMemory = json[@"totalMemory"];
    }
    return device;
}

+ (RSCrashReporterDevice *)deviceWithKSCrashReport:(NSDictionary *)event {
    RSCrashReporterDevice *device = [RSCrashReporterDevice new];
    [self populateFields:device dictionary:event];
    return device;
}

+ (void)populateFields:(RSCrashReporterDevice *)device
            dictionary:(NSDictionary *)event {
    NSDictionary *system = event[@"system"];
    device.jailbroken = [system[@RSC_KSSystemField_Jailbroken] boolValue];
    device.id = nil; //system[@RSC_KSSystemField_DeviceAppHash];
    device.locale = [[NSLocale currentLocale] localeIdentifier];
    device.manufacturer = @"Apple";
    device.model = system[@RSC_KSSystemField_Machine];
    device.modelNumber = system[@RSC_KSSystemField_Model];
    device.osName = system[@RSC_KSSystemField_SystemName];
    device.osVersion = system[@RSC_KSSystemField_SystemVersion];
    device.totalMemory = system[@ RSC_KSSystemField_Memory][@ RSC_KSCrashField_Size];

    NSMutableDictionary *runtimeVersions = [NSMutableDictionary new];
    runtimeVersions[@"osBuild"] = system[@RSC_KSSystemField_OSVersion];
    runtimeVersions[@"clangVersion"] = system[@RSC_KSSystemField_ClangVersion];
    device.runtimeVersions = runtimeVersions;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"jailbroken"] = @(self.jailbroken);
    dict[@"id"] = nil; //self.id;
    dict[@"locale"] = self.locale;
    dict[@"manufacturer"] = self.manufacturer;
    dict[@"model"] = self.model;
    dict[@"modelNumber"] = self.modelNumber;
    dict[@"osName"] = self.osName;
    dict[@"osVersion"] = self.osVersion;
    dict[@"runtimeVersions"] = self.runtimeVersions;
    dict[@"totalMemory"] = self.totalMemory;
    return dict;
}

- (void)appendRuntimeInfo:(NSDictionary *)info {
    NSMutableDictionary *versions = [self.runtimeVersions mutableCopy];
    [versions addEntriesFromDictionary:info];
    self.runtimeVersions = versions;
}

@end
