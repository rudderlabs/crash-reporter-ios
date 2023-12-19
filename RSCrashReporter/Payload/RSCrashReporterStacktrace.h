//
//  RSCrashReporterStacktrace.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 06/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"

@class RSCrashReporterStackframe;

/**
 * Representation of a stacktrace in a bugsnag error report
 */
RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterStacktrace : NSObject

- (instancetype)initWithTrace:(NSArray<NSDictionary *> *)trace
                 binaryImages:(NSArray<NSDictionary *> *)binaryImages;

+ (instancetype)stacktraceFromJson:(NSArray<NSDictionary *> *)json;

@property (nonatomic) NSMutableArray<RSCrashReporterStackframe *> *trace;

@end
