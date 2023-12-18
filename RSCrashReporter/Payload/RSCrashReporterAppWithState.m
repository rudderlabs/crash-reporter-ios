//
//  RSCrashReporterAppWithState.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterAppWithState+Private.h"

#import "RSCKeys.h"
#import "RSC_KSCrashReportFields.h"
#import "RSCrashReporterApp+Private.h"

@implementation RSCrashReporterAppWithState

+ (RSCrashReporterAppWithState *)appFromJson:(NSDictionary *)json {
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState new];

    id duration = json[@"duration"];
    if ([duration isKindOfClass:[NSNumber class]]) {
        app.duration = duration;
    }

    id durationInForeground = json[@"durationInForeground"];
    if ([durationInForeground isKindOfClass:[NSNumber class]]) {
        app.durationInForeground = durationInForeground;
    }

    id inForeground = json[@"inForeground"];
    if (inForeground) {
        app.inForeground = [(NSNumber *) inForeground boolValue];
    }

    NSArray *dsyms = json[@"dsymUUIDs"];

    if (dsyms.count) {
        app.dsymUuid = dsyms[0];
    }

    app.binaryArch = json[@"binaryArch"];
    app.bundleVersion = json[@"bundleVersion"];
    app.codeBundleId = json[@"codeBundleId"];
    app.id = json[@"id"];
    app.releaseStage = json[@"releaseStage"];
    app.type = json[@"type"];
    app.version = json[@"version"];
    app.isLaunching = [json[@"isLaunching"] boolValue];
    return app;
}

+ (RSCrashReporterAppWithState *)appWithDictionary:(NSDictionary *)event
                                    config:(RSCrashReporterConfiguration *)config
                              codeBundleId:(NSString *)codeBundleId
{
    RSCrashReporterAppWithState *app = [RSCrashReporterAppWithState new];
    NSDictionary *system = event[RSCKeySystem];
    NSDictionary *stats = system[@RSC_KSCrashField_AppStats];

    // convert from seconds to milliseconds
    NSNumber *activeTimeSinceLaunch = @((int)([stats[@RSC_KSCrashField_ActiveTimeSinceLaunch] doubleValue] * 1000.0));
    NSNumber *backgroundTimeSinceLaunch = @((int)([stats[@RSC_KSCrashField_BGTimeSinceLaunch] doubleValue] * 1000.0));

    app.durationInForeground = activeTimeSinceLaunch;
    app.duration = @([activeTimeSinceLaunch longValue] + [backgroundTimeSinceLaunch longValue]);
    app.inForeground = [stats[@RSC_KSCrashField_AppInFG] boolValue];
    app.isLaunching = [[event valueForKeyPath:@"user.isLaunching"] boolValue];
    [RSCrashReporterApp populateFields:app dictionary:event config:config codeBundleId:codeBundleId];
    return app;
}

- (NSDictionary *)toDict
{
    NSMutableDictionary *dict = [[super toDict] mutableCopy];
    dict[@"duration"] = self.duration;
    dict[@"durationInForeground"] = self.durationInForeground;
    dict[@"inForeground"] = @(self.inForeground);
    dict[@"isLaunching"] = @(self.isLaunching);
    return dict;
}

@end
