//
//  RSCrashReporterThreadTests.m
//  Tests
//
//  Created by Jamie Lynch on 07/04/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSC_KSMachHeaders.h"
#import "RSCrashReporterStackframe+Private.h"
#import "RSCrashReporterThread+Private.h"

#import <pthread.h>
#import <stdatomic.h>

@interface RSCrashReporterThreadTests : XCTestCase
@property NSArray *binaryImages;
@property NSDictionary *thread;
@end

@implementation RSCrashReporterThreadTests

+ (void)setUp {
    rsc_mach_headers_initialize();
    rsc_mach_headers_get_images(); // Ensure call stack can be symbolicated
}

- (void)setUp {
    self.thread = @{
            @"current_thread": @YES,
            @"crashed": @YES,
            @"index": @4,
            @"state": @"TH_STATE_RUNNING",
            @"backtrace": @{
                    @"skipped": @0,
                    @"contents": @[
                            @{
                                    @"symbol_name": @"kscrashsentry_reportUserException",
                                    @"symbol_addr": @4491038467,
                                    @"instruction_addr": @4491038575,
                                    @"object_name": @"CrashProbeiOS",
                                    @"object_addr": @4490747904
                            }
                    ]
            },
    };
    self.binaryImages = @[@{
            @"uuid": @"D0A41830-4FD2-3B02-A23B-0741AD4C7F52",
            @"image_vmaddr": @4294967296,
            @"image_addr": @4490747904,
            @"image_size": @483328,
            @"name": @"/Users/joesmith/foo",
    }];
}

- (void)testThreadFromDict {
    RSCrashReporterThread *thread = [[RSCrashReporterThread alloc] initWithThread:self.thread binaryImages:self.binaryImages];
    XCTAssertNotNil(thread);

    XCTAssertEqualObjects(@"4", thread.id);
    XCTAssertNil(thread.name);
    XCTAssertEqual(RSCThreadTypeCocoa, thread.type);
    XCTAssertTrue(thread.errorReportingThread);

    // validate stacktrace
    XCTAssertEqual(1, [thread.stacktrace count]);
    RSCrashReporterStackframe *frame = thread.stacktrace[0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame.method);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame.machoFile);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame.machoUuid);
}

- (void)testThreadToDict {
    RSCrashReporterThread *thread = [[RSCrashReporterThread alloc] initWithThread:self.thread binaryImages:self.binaryImages];
    thread.name = @"bugsnag-thread-1";

    NSDictionary *dict = [thread toDictionary];
    XCTAssertEqualObjects(@"4", dict[@"id"]);
    XCTAssertEqualObjects(@"bugsnag-thread-1", dict[@"name"]);
    XCTAssertEqualObjects(@"cocoa", dict[@"type"]);
    XCTAssertEqualObjects(@"TH_STATE_RUNNING", dict[@"state"]);
    XCTAssertTrue([dict[@"errorReportingThread"] boolValue]);

    // validate stacktrace
    XCTAssertEqual(1, [dict[@"stacktrace"] count]);
    NSDictionary *frame = dict[@"stacktrace"][0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame[@"method"]);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame[@"machoFile"]);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame[@"machoUUID"]);
}

/**
 * Dictionary info not enhanced if not an error reporting thread
 */
- (void)testThreadEnhancementNotCrashed {
    NSDictionary *dict = @{
            @"backtrace": @{
                    @"contents": @[
                            @{@"instruction_addr": @304},
                            @{@"instruction_addr": @204},
                            @{@"instruction_addr": @104}
                    ]
            },
            @"registers": @{
                @"basic": @{
#if TARGET_CPU_ARM || TARGET_CPU_ARM64
                    @"pc": @304,
                    @"lr": @204
#elif TARGET_CPU_X86
                    @"eip": @304
#elif TARGET_CPU_X86_64
                    @"rip": @304
#else
#error Unsupported CPU architecture
#endif
                }
            }
    };
    NSDictionary *thread = [RSCrashReporterThread enhanceThreadInfo:dict];
    XCTAssertEqual(dict, thread);
}

/**
 * Frames enhanced with lc/pr info
 */
- (void)testThreadEnhancementLcPr {
    NSDictionary *dict = @{
            @"backtrace": @{
                    @"contents": @[
                            @{@"instruction_addr": @304},
                            @{@"instruction_addr": @204},
                            @{@"instruction_addr": @104}
                    ]
            },
            @"crashed": @YES,
            @"registers": @{
                @"basic": @{
#if TARGET_CPU_ARM || TARGET_CPU_ARM64
                    @"pc": @304,
                    @"lr": @204
#elif TARGET_CPU_X86
                    @"eip": @304
#elif TARGET_CPU_X86_64
                    @"rip": @304
#else
#error Unsupported CPU architecture
#endif
                }
            }
    };
    NSDictionary *thread = [RSCrashReporterThread enhanceThreadInfo:dict];
    XCTAssertNotEqual(dict, thread);
    NSArray *trace = thread[@"backtrace"][@"contents"];
    XCTAssertEqual(3, [trace count]);

    XCTAssertEqualObjects(trace[0][@"isPC"], @YES);
    XCTAssertEqualObjects(trace[0][@"isLR"], nil);

    XCTAssertEqualObjects(trace[1][@"isPC"], nil);
#if TARGET_CPU_ARM || TARGET_CPU_ARM64
    XCTAssertEqualObjects(trace[1][@"isLR"], @YES);
#else
    XCTAssertEqualObjects(trace[1][@"isLR"], nil);
#endif

    XCTAssertEqualObjects(trace[2][@"isPC"], nil);
    XCTAssertEqualObjects(trace[2][@"isLR"], nil);
}

- (void)testStacktraceOverride {
    RSCrashReporterThread *thread = [[RSCrashReporterThread alloc] initWithThread:self.thread binaryImages:self.binaryImages];
    XCTAssertNotNil(thread.stacktrace);
    XCTAssertEqual(1, thread.stacktrace.count);
    thread.stacktrace = @[];
    XCTAssertEqual(0, thread.stacktrace.count);
}

// MARK: - RSCrashReporterThread (Recording)

- (void)testAllThreads {
    NSArray<RSCrashReporterThread *> *threads = [RSCrashReporterThread allThreads:YES callStackReturnAddresses:NSThread.callStackReturnAddresses];
    [threads[0].stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
    XCTAssertTrue(threads[0].errorReportingThread);
    XCTAssertEqualObjects(threads[0].name, @"com.apple.main-thread");
    XCTAssertEqualObjects(threads[0].stacktrace.firstObject.method, @(__PRETTY_FUNCTION__));
    XCTAssertGreaterThan(threads.count, 1);
}

static void * executeBlock(void *ptr) {
    ((__bridge_transfer dispatch_block_t)ptr)();
    return NULL;
}

- (void)testAllThreadsFromBackgroundDoesNotOverflowStack {
    const int threadCount = 1000;
    pthread_t pthreads[threadCount];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    for (int i = 0; i < threadCount; i++) {
        pthread_create(pthreads + i, NULL, executeBlock, (__bridge_retained void *)^{
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        });
    }
    __block NSArray<RSCrashReporterThread *> *threads = nil;
    dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        threads = [RSCrashReporterThread allThreads:YES callStackReturnAddresses:NSThread.callStackReturnAddresses];
    });
    XCTAssertGreaterThan(threads.count, threadCount);
    for (int i = 0; i < threadCount; i++) {
        dispatch_semaphore_signal(semaphore);
    }
    for (int i = 0; i < threadCount; i++) {
        pthread_join(pthreads[i], 0);
    }
}

- (void)testCurrentThread {
    NSArray<RSCrashReporterThread *> *threads = [RSCrashReporterThread allThreads:NO callStackReturnAddresses:NSThread.callStackReturnAddresses];
    [threads[0].stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
    XCTAssertEqual(threads.count, 1);
    XCTAssertTrue(threads[0].errorReportingThread);
    XCTAssertEqualObjects(threads[0].id, @"0");
    XCTAssertEqualObjects(threads[0].state, @"TH_STATE_RUNNING");
    XCTAssertEqualObjects(threads[0].name, @"com.apple.main-thread");
    XCTAssertEqualObjects(threads[0].stacktrace.firstObject.method, @(__PRETTY_FUNCTION__));
}

- (void)testCurrentThreadFromBackground {
    __block RSCrashReporterThread *thread = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Thread recorded in background"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        thread = [RSCrashReporterThread allThreads:NO callStackReturnAddresses:NSThread.callStackReturnAddresses][0];
        [thread.stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertTrue(thread.errorReportingThread);
    XCTAssertGreaterThan(thread.id.intValue, 0);
    XCTAssertNotNil(thread.name);
    XCTAssertNotNil(thread.state);
    XCTAssertNotEqualObjects(thread.name, @"com.apple.main-thread");
    XCTAssert([thread.stacktrace.firstObject.method hasSuffix:@"_block_invoke"]);
}

- (void)testMainThread {
    RSCrashReporterThread *thread = [RSCrashReporterThread mainThread];
    XCTAssertNil(thread);
}

- (void)testMainThreadFromBackground {
    NSParameterAssert(NSThread.currentThread.isMainThread);
    __block RSCrashReporterThread *thread = nil;
    __block atomic_int state = 0;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (atomic_load(&state) != 1) {
            // Wait for main thread to be back in -testMainThreadFromBackground
        }
        thread = [RSCrashReporterThread mainThread];
        [thread.stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
        atomic_store(&state, 2);
    });
    atomic_store(&state, 1);
    while (atomic_load(&state) != 2) {
        // Wait for `thread` to be set by background queue.
        // Busy waiting so that this method will appear at the top of the stack trace.
    }
    XCTAssertTrue(thread.errorReportingThread);
    XCTAssertEqualObjects(thread.id, @"0");
    XCTAssertEqualObjects(thread.state, @"TH_STATE_RUNNING");
    XCTAssertEqualObjects(thread.name, @"com.apple.main-thread");
    XCTAssertEqualObjects(thread.stacktrace.firstObject.method, @(__PRETTY_FUNCTION__));
}

@end
