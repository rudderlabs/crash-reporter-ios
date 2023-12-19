//
//  RSCrashReporterThread+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 23/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "RSCDefines.h"
#import "RSCrashReporterInternals.h"

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterThread ()

- (instancetype)initWithId:(nullable NSString *)identifier
                      name:(nullable NSString *)name
      errorReportingThread:(BOOL)errorReportingThread
                      type:(RSCThreadType)type
                     state:(nullable NSString *)state
                stacktrace:(NSArray<RSCrashReporterStackframe *> *)stacktrace;

- (instancetype)initWithThread:(NSDictionary *)thread binaryImages:(NSArray *)binaryImages;

@property (readonly, nullable, nonatomic) NSString *crashInfoMessage;

@property (readwrite, nonatomic) BOOL errorReportingThread;

+ (NSDictionary *)enhanceThreadInfo:(NSDictionary *)thread;

#if RSC_HAVE_MACH_THREADS
+ (nullable instancetype)mainThread;
#endif

+ (NSMutableArray<RSCrashReporterThread *> *)threadsFromArray:(NSArray *)threads binaryImages:(NSArray *)binaryImages;

- (NSDictionary *)toDictionary;

@end

RSCThreadType RSCParseThreadType(NSString *type);

NSString *RSCSerializeThreadType(RSCThreadType type);

NS_ASSUME_NONNULL_END
