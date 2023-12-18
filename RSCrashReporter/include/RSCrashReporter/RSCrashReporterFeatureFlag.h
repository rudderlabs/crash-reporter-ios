//
//  RSCrashReporterFeatureFlag.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>

NS_ASSUME_NONNULL_BEGIN

RSCRASHREPORTER_EXTERN
@interface RSCrashReporterFeatureFlag : NSObject

+ (instancetype)flagWithName:(NSString *)name;

+ (instancetype)flagWithName:(NSString *)name variant:(nullable NSString *)variant;

@property (readonly, nonatomic) NSString *name;

@property (nullable, readonly, nonatomic) NSString *variant;

@end

NS_ASSUME_NONNULL_END
