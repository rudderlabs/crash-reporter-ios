//
//  RSCrashReporterApp.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import "RSCrashReporterApp.h"

#import "RSCKeys.h"
#import "RSCRunContext.h"
#import "RSC_KSSystemInfo.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterConfiguration.h"

/**
 * Parse an event dictionary representation for App-specific metadata.
 *
 * @returns A dictionary of app-specific metadata
 */
NSDictionary *RSCParseAppMetadata(NSDictionary *event) {
    NSMutableDictionary *app = [NSMutableDictionary new];
    app[@"name"] = [event valueForKeyPath:@"system." RSC_KSSystemField_BundleExecutable];
    app[@"runningOnRosetta"] = [event valueForKeyPath:@"system." RSC_KSSystemField_Translated];
    return app;
}

NSDictionary *RSCAppMetadataFromRunContext(const struct RSCRunContext *context) {
    NSMutableDictionary *app = [NSMutableDictionary dictionary];
    if (context->memoryLimit) {
        app[RSCKeyFreeMemory] = @(context->memoryAvailable);
        app[RSCKeyMemoryLimit] = @(context->memoryLimit);
    }
    if (context->memoryFootprint) {
        app[RSCKeyMemoryUsage] = @(context->memoryFootprint);
    }
    return app;
}

@implementation RSCrashReporterApp

+ (RSCrashReporterApp *)deserializeFromJson:(NSDictionary *)json {
    RSCrashReporterApp *app = [RSCrashReporterApp new];
    if (json != nil) {
        app.binaryArch = json[@"binaryArch"];
        app.bundleVersion = json[@"bundleVersion"];
        app.codeBundleId = json[@"codeBundleId"];
        app.id = json[@"id"];
        app.releaseStage = json[@"releaseStage"];
        app.type = json[@"type"];
        app.version = json[@"version"];
        app.dsymUuid = [json[@"dsymUUIDs"] firstObject];
    }
    return app;
}

+ (RSCrashReporterApp *)appWithDictionary:(NSDictionary *)event
                           config:(RSCrashReporterConfiguration *)config
                     codeBundleId:(NSString *)codeBundleId
{
    RSCrashReporterApp *app = [RSCrashReporterApp new];
    [self populateFields:app
              dictionary:event
                  config:config
            codeBundleId:codeBundleId];
    return app;
}

+ (void)populateFields:(RSCrashReporterApp *)app
            dictionary:(NSDictionary *)event
                config:(RSCrashReporterConfiguration *)config
          codeBundleId:(NSString *)codeBundleId
{
    NSDictionary *system = event[RSCKeySystem];
    app.id = system[@RSC_KSSystemField_BundleID];
    app.binaryArch = system[@RSC_KSSystemField_BinaryArch];
    app.bundleVersion = system[@RSC_KSSystemField_BundleVersion];
    app.dsymUuid = system[@RSC_KSSystemField_AppUUID];
    app.version = system[@RSC_KSSystemField_BundleShortVersion];
    app.codeBundleId = [event valueForKeyPath:@"user.state.app.codeBundleId"] ?: codeBundleId;
    [app setValuesFromConfiguration:config];
}

- (void)setValuesFromConfiguration:(RSCrashReporterConfiguration *)configuration
{
    if (configuration.appType) {
        self.type = configuration.appType;
    }
    if (configuration.appVersion) {
        self.version = configuration.appVersion;
    }
    if (configuration.bundleVersion) {
        self.bundleVersion = configuration.bundleVersion;
    }
    if (configuration.releaseStage) {
        self.releaseStage = configuration.releaseStage;
    }
}

- (NSDictionary *)toDict
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"binaryArch"] = self.binaryArch;
    dict[@"bundleVersion"] = self.bundleVersion;
    dict[@"codeBundleId"] = self.codeBundleId;
    dict[@"dsymUUIDs"] = RSCArrayWithObject(self.dsymUuid);
    dict[@"id"] = self.id;
    dict[@"releaseStage"] = self.releaseStage;
    dict[@"type"] = self.type;
    dict[@"version"] = self.version;
    return dict;
}

@end
