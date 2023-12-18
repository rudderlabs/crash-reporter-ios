//
//  RSC_KSCrashReportTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 06/01/2022.
//  Copyright © 2022 RSCrashReporter Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSC_KSCrashC.h"
#import "RSC_KSCrashReport.h"
#import "RSC_KSCrashSentry_Private.h"
#import "RSC_KSMach.h"
#import "RSCDefines.h"

#import <execinfo.h>

@interface RSC_KSCrashReportTests : XCTestCase

@end

@implementation RSC_KSCrashReportTests

- (void)testBinaryImages {
    NSString *crashReportFilePath = [self temporaryFile:@"crash_report.json"];
    NSString *recrashReportFilePath = [self temporaryFile:@"recrash_report"];
    NSString *stateFilePath = [self temporaryFile:@"kscrash_state"];
    NSString *crashID = [[NSUUID UUID] UUIDString];
    
    rsc_kscrash_init();
    rsc_kscrash_setHandlingCrashTypes(RSC_KSCrashTypeNSException);
    rsc_kscrash_install([crashReportFilePath fileSystemRepresentation],
                        [recrashReportFilePath fileSystemRepresentation],
                        [stateFilePath fileSystemRepresentation],
                        [crashID UTF8String]);
    
    uintptr_t stackTrace[500];
    
    RSC_KSCrash_Context *context = crashContext();
    context->crash.crashType = RSC_KSCrashTypeNSException;
    context->crash.offendingThread = rsc_ksmachthread_self();
    context->crash.registersAreValid = false;
    context->crash.NSException.name = "RSC_KSCrashReportTests";
    context->crash.crashReason = "testBinaryImages";
    context->crash.stackTrace = stackTrace;
    context->crash.stackTraceLength = backtrace((void **)stackTrace, sizeof(stackTrace) / sizeof(*stackTrace));
    context->crash.threadTracingEnabled = false;
    
    const char *reportPath = [crashReportFilePath fileSystemRepresentation];
#if RSC_HAVE_MACH_THREADS
    rsc_kscrashsentry_suspendThreads();
#endif
    rsc_kscrashreport_writeStandardReport(context, reportPath);
#if RSC_HAVE_MACH_THREADS
    rsc_kscrashsentry_resumeThreads();
#endif
    
    NSDictionary *report = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:crashReportFilePath] options:0 error:nil];
    
    NSArray *binaryImages = [report valueForKeyPath:@"binary_images"];
    XCTAssert([binaryImages isKindOfClass:[NSArray class]]);
    NSSet *binaryImageAddrs = [NSSet setWithArray:[binaryImages valueForKeyPath:@"image_addr"]];
    
    NSMutableSet *backtraceImageAddrs = [NSMutableSet setWithArray:[report valueForKeyPath:@"crash.threads.@distinctUnionOfArrays.backtrace.contents.object_addr"]];
    [backtraceImageAddrs removeObject:[NSNull null]];
    
    XCTAssertEqualObjects(binaryImageAddrs, backtraceImageAddrs);
}

- (void)testWriteStandardReportPerformance {
    NSString *crashReportFilePath = [self temporaryFile:@"crash_report"];
    NSString *recrashReportFilePath = [self temporaryFile:@"recrash_report"];
    NSString *stateFilePath = [self temporaryFile:@"kscrash_state"];
    NSString *crashID = [[NSUUID UUID] UUIDString];
    
    rsc_kscrash_init();
    rsc_kscrash_setHandlingCrashTypes(RSC_KSCrashTypeNSException);
    rsc_kscrash_install([crashReportFilePath fileSystemRepresentation],
                        [recrashReportFilePath fileSystemRepresentation],
                        [stateFilePath fileSystemRepresentation],
                        [crashID UTF8String]);
    
    // Make a fake stack trace with addresses from a library (Foundation) that will generate a non-trivial symbolication workload.
    
    const int numFrames = 500;
    uintptr_t stackTrace[numFrames];
    for (int i = 0; i < numFrames; i++) {
        stackTrace[i] = (uintptr_t)NSLog;
        assert(stackTrace[i] != 0);
    }
    
    RSC_KSCrash_Context *context = crashContext();
    context->crash.crashType = RSC_KSCrashTypeNSException;
    context->crash.offendingThread = rsc_ksmachthread_self();
    context->crash.registersAreValid = false;
    context->crash.NSException.name = "RSC_KSCrashReportTests";
    context->crash.crashReason = "testWriteStandardReportPerformance";
    context->crash.stackTrace = stackTrace;
    context->crash.stackTraceLength = numFrames;
    context->crash.threadTracingEnabled = true;
    
    [self measureMetrics:[[self class] defaultPerformanceMetrics] automaticallyStartMeasuring:NO forBlock:^{
        const char *reportPath = [crashReportFilePath fileSystemRepresentation];
        
        [self startMeasuring]; {
#if RSC_HAVE_MACH_THREADS
            rsc_kscrashsentry_suspendThreads();
#endif
            rsc_kscrashreport_writeStandardReport(context, reportPath);
#if RSC_HAVE_MACH_THREADS
            rsc_kscrashsentry_resumeThreads();
#endif
        }
        [self stopMeasuring];
        
        NSDictionary *report = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:crashReportFilePath] options:0 error:nil];
        XCTAssert([report isKindOfClass:[NSDictionary class]], @"%@", report);
        [[NSFileManager defaultManager] removeItemAtPath:crashReportFilePath error:nil];
    }];
}

- (NSString *)temporaryFile:(NSString *)fileName {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    [self addTeardownBlock:^{
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }];
    return path;
}

@end
