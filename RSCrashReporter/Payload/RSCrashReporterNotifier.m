//
//  RSCrashReporterNotifier.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 29/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterNotifier.h"

@implementation RSCrashReporterNotifier

- (instancetype)init {
    if ((self = [super init])) {
#if TARGET_OS_TV
        _name = @"tvOS RSCrashReporter Notifier";
#elif TARGET_OS_IOS
        _name = @"iOS RSCrashReporter Notifier";
#elif TARGET_OS_OSX
        _name = @"OSX RSCrashReporter Notifier";
#elif TARGET_OS_WATCH
        _name = @"watchOS RSCrashReporter Notifier";
#else
        _name = @"RSCrashReporter Objective-C";
#endif
        _version = @"6.27.0";
        _url = @"https://github.com/bugsnag/bugsnag-cocoa";
        _dependencies = @[];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                     version:(NSString *)version
                         url:(NSString *)url
                dependencies:(NSArray<RSCrashReporterNotifier *> *)dependencies {
    if ((self = [super init])) {
        _name = [name copy];
        _version = [version copy];
        _url = [url copy];
        _dependencies = [dependencies copy];
    }
    return self;
}

- (NSDictionary *)toDict {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"name"] = self.name;
    dict[@"version"] = self.version;
    dict[@"url"] = self.url;

    if ([self.dependencies count] > 0) {
        NSMutableArray *values = [NSMutableArray new];
        dict[@"dependencies"] = values;

        for (RSCrashReporterNotifier *notifier in self.dependencies) {
            [values addObject:[notifier toDict]];
        }
    }
    return dict;
}

@end
