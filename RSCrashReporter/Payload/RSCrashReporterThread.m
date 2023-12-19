//
//  RSCrashReporterThread.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterThread+Private.h"

#import "RSCKeys.h"
#import "RSC_KSBacktrace_Private.h"
#import "RSC_KSCrashReportFields.h"
#import "RSC_KSCrashSentry_Private.h"
#import "RSC_KSMach.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterStackframe+Private.h"
#import "RSCrashReporterStacktrace.h"
#import "RSCrashReporterThread+Private.h"
#import "RSC_KSCrashNames.h"
#import "RSCDefines.h"

#include <pthread.h>

#if RSC_HAVE_MACH_THREADS
// Protect access to thread-unsafe rsc_kscrashsentry_suspendThreads()
static pthread_mutex_t rsc_suspend_threads_mutex = PTHREAD_MUTEX_INITIALIZER;

static void suspend_threads(void) {
    pthread_mutex_lock(&rsc_suspend_threads_mutex);
    rsc_kscrashsentry_suspendThreads();
}

static void resume_threads(void) {
    rsc_kscrashsentry_resumeThreads();
    pthread_mutex_unlock(&rsc_suspend_threads_mutex);
}
#endif

static NSString * thread_state_name(integer_t threadState) {
    const char* stateCName = rsc_kscrashthread_state_name(threadState);
    return stateCName ? [NSString stringWithUTF8String:stateCName] : nil;
}

#define kMaxAddresses 150 // same as RSC_kMaxBacktraceDepth

struct backtrace_t {
    NSUInteger length;
    uintptr_t addresses[kMaxAddresses];
};

#if RSC_HAVE_MACH_THREADS
static void backtrace_for_thread(thread_t thread, struct backtrace_t *output) {
    RSC_STRUCT_MCONTEXT_L machineContext = {{0}};
    if (rsc_ksmachthreadState(thread, &machineContext)) {
        output->length = (NSUInteger)rsc_ksbt_backtraceThreadState(&machineContext, output->addresses, 0, kMaxAddresses);
    } else {
        output->length = 0;
    }
}
#endif

RSCThreadType RSCParseThreadType(NSString *type) {
    return [@"cocoa" isEqualToString:type] ? RSCThreadTypeCocoa : RSCThreadTypeReactNativeJs;
}

NSString *RSCSerializeThreadType(RSCThreadType type) {
    return type == RSCThreadTypeCocoa ? @"cocoa" : @"reactnativejs";
}

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterThread

+ (instancetype)threadFromJson:(NSDictionary *)json {
    if (json == nil) {
        return nil;
    }
    NSString *type = json[@"type"];
    RSCThreadType threadType = RSCParseThreadType(type);
    BOOL errorReportingThread = json[@"errorReportingThread"] && [json[@"errorReportingThread"] boolValue];
    NSArray<RSCrashReporterStackframe *> *stacktrace = [RSCrashReporterStacktrace stacktraceFromJson:json[RSCKeyStacktrace]].trace;
    RSCrashReporterThread *thread = [[RSCrashReporterThread alloc] initWithId:json[@"id"]
                                                         name:json[@"name"]
                                         errorReportingThread:errorReportingThread
                                                         type:threadType
                                                        state:json[@"state"]
                                                   stacktrace:stacktrace];
    return thread;
}

- (instancetype)initWithId:(NSString *)id
                      name:(NSString *)name
      errorReportingThread:(BOOL)errorReportingThread
                      type:(RSCThreadType)type
                     state:(NSString *)state
                stacktrace:(NSArray<RSCrashReporterStackframe *> *)stacktrace {
    if ((self = [super init])) {
        _id = id;
        _name = name;
        _errorReportingThread = errorReportingThread;
        _type = type;
        _state = state;
        _stacktrace = stacktrace;
    }
    return self;
}

- (instancetype)initWithThread:(NSDictionary *)thread binaryImages:(NSArray *)binaryImages {
    if ((self = [super init])) {
        _errorReportingThread = [thread[@RSC_KSCrashField_Crashed] boolValue];
        _id = [thread[@RSC_KSCrashField_Index] stringValue];
        _name = thread[@RSC_KSCrashField_Name];
        _type = RSCThreadTypeCocoa;
        _state = thread[@RSC_KSCrashField_State];
        _crashInfoMessage = [thread[@RSC_KSCrashField_CrashInfoMessage] copy];
        NSArray *backtrace = thread[@RSC_KSCrashField_Backtrace][@RSC_KSCrashField_Contents];
        RSCrashReporterStacktrace *frames = [[RSCrashReporterStacktrace alloc] initWithTrace:backtrace binaryImages:binaryImages];
        _stacktrace = [frames.trace copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"id"] = self.id;
    dict[@"name"] = self.name;
    dict[@"errorReportingThread"] = @(self.errorReportingThread);
    dict[@"type"] = RSCSerializeThreadType(self.type);
    dict[@"state"] = self.state;
    dict[@"errorReportingThread"] = @(self.errorReportingThread);

    NSMutableArray *array = [NSMutableArray new];
    for (RSCrashReporterStackframe *frame in self.stacktrace) {
        [array addObject:[frame toDictionary]];
    }
    dict[@"stacktrace"] = array;
    return dict;
}

/**
 * Converts bugsnag threads to JSON
 */
+ (NSMutableArray *)serializeThreads:(NSArray<RSCrashReporterThread *> *)threads {
    NSMutableArray *threadArray = [NSMutableArray new];
    for (RSCrashReporterThread *thread in threads) {
        [threadArray addObject:[thread toDictionary]];
    }
    return threadArray;
}

/**
 * Deerializes RSCrashReporter Threads from a KSCrash report
 */
+ (NSMutableArray<RSCrashReporterThread *> *)threadsFromArray:(NSArray *)threads binaryImages:(NSArray *)binaryImages {
    NSMutableArray *bugsnagThreads = [NSMutableArray new];

    for (NSDictionary *thread in threads) {
        NSDictionary *threadInfo = [self enhanceThreadInfo:thread];
        RSCrashReporterThread *obj = [[RSCrashReporterThread alloc] initWithThread:threadInfo binaryImages:binaryImages];
        [bugsnagThreads addObject:obj];
    }
    return bugsnagThreads;
}

/**
 * Adds isPC and isLR values to a KSCrashReport thread dictionary.
 */
+ (NSDictionary *)enhanceThreadInfo:(NSDictionary *)thread {
    NSArray *backtrace = thread[@"backtrace"][@"contents"];
    BOOL isReportingThread = [thread[@"crashed"] boolValue];

    if (isReportingThread) {
        NSDictionary *registers = thread[@ RSC_KSCrashField_Registers][@ RSC_KSCrashField_Basic];
#if TARGET_CPU_ARM || TARGET_CPU_ARM64
        NSNumber *pc = registers[@"pc"];
        NSNumber *lr = registers[@"lr"];
#elif TARGET_CPU_X86
        NSNumber *pc = registers[@"eip"];
        NSNumber *lr = nil;
#elif TARGET_CPU_X86_64
        NSNumber *pc = registers[@"rip"];
        NSNumber *lr = nil;
#else
#error Unsupported CPU architecture
#endif

        NSMutableArray *stacktrace = [NSMutableArray array];

        for (NSDictionary *frame in backtrace) {
            NSMutableDictionary *mutableFrame = [frame mutableCopy];
            NSNumber *instructionAddress = frame[@ RSC_KSCrashField_InstructionAddr]; 
            if ([instructionAddress isEqual:pc]) {
                mutableFrame[RSCKeyIsPC] = @YES;
            }
            if ([instructionAddress isEqual:lr]) {
                mutableFrame[RSCKeyIsLR] = @YES;
            }
            [stacktrace addObject:mutableFrame];
        }
        NSMutableDictionary *mutableBacktrace = [thread[@"backtrace"] mutableCopy];
        mutableBacktrace[@"contents"] = stacktrace;
        NSMutableDictionary *mutableThread = [thread mutableCopy];
        mutableThread[@"backtrace"] = mutableBacktrace;
        return mutableThread;
    }
    return thread;
}

// MARK: - Recording

+ (NSArray<RSCrashReporterThread *> *)allThreads:(BOOL)allThreads callStackReturnAddresses:(NSArray<NSNumber *> *)callStackReturnAddresses {
    struct backtrace_t backtrace;
    backtrace.length = MIN(callStackReturnAddresses.count, kMaxAddresses);
    for (NSUInteger i = 0; i < (NSUInteger)backtrace.length; i++) {
        backtrace.addresses[i] = (uintptr_t)callStackReturnAddresses[i].unsignedLongLongValue;
    }
    if (allThreads) {
        return [RSCrashReporterThread allThreadsWithCurrentThreadBacktrace:&backtrace];
    } else {
        return @[[RSCrashReporterThread currentThreadWithBacktrace:&backtrace]];
    }
}

+ (NSArray<RSCrashReporterThread *> *)allThreadsWithCurrentThreadBacktrace:(struct backtrace_t *)currentThreadBacktrace {
    integer_t *threadStates = NULL;
    unsigned threadCount = 0;

    thread_t *threads = rsc_ksmachgetAllThreads(&threadCount);
    if (threads == NULL) {
        return @[];
    }

    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:threadCount];

    struct backtrace_t *backtraces = calloc(threadCount, sizeof(struct backtrace_t));
    if (!backtraces) {
        goto cleanup;
    }

    threadStates = calloc(threadCount, sizeof(*threadStates));
    if (!threadStates) {
        goto cleanup;
    }
    rsc_ksmachgetThreadStates(threads, threadStates, threadCount);

#if RSC_HAVE_MACH_THREADS
    suspend_threads();

    // While threads are suspended only async-signal-safe functions should be used,
    // as another threads may have been suspended while holding a lock in malloc,
    // the Objective-C runtime, or other subsystems.

    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        BOOL isCurrentThread = MACH_PORT_INDEX(threads[i]) == MACH_PORT_INDEX(rsc_ksmachthread_self());
        if (isCurrentThread) {
            backtraces[i].length = 0; // currentThreadBacktrace will be used instead
        } else {
            backtrace_for_thread(threads[i], &backtraces[i]);
        }
    }

    resume_threads();
#endif

    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        BOOL isCurrentThread = MACH_PORT_INDEX(threads[i]) == MACH_PORT_INDEX(rsc_ksmachthread_self());
        struct backtrace_t *backtrace = isCurrentThread ? currentThreadBacktrace : &backtraces[i];
        [objects addObject:[[RSCrashReporterThread alloc] initWithMachThread:threads[i]
                                                               state:thread_state_name(threadStates[i])
                                                  backtraceAddresses:backtrace->addresses
                                                     backtraceLength:backtrace->length
                                                errorReportingThread:isCurrentThread
                                                               index:i]];
    }

cleanup:
    rsc_ksmachfreeThreads(threads, threadCount);
    free(backtraces);
    free(threadStates);
    return objects;
}

+ (instancetype)currentThreadWithBacktrace:(struct backtrace_t *)backtrace {
    thread_t selfThread = mach_thread_self();
    NSString *threadState = thread_state_name(rsc_ksmachgetThreadState(selfThread));

    unsigned threadCount = 0;
    thread_t *threads = rsc_ksmachgetAllThreads(&threadCount);
    unsigned threadIndex = 0;
    if (threads != NULL) {
        for (unsigned i = 0; i < threadCount; i++) {
            if (MACH_PORT_INDEX(threads[i]) == MACH_PORT_INDEX(selfThread)) {
                threadIndex = i;
                break;
            }
        }
    }
    rsc_ksmachfreeThreads(threads, threadCount);

    return [[RSCrashReporterThread alloc] initWithMachThread:selfThread
                                               state:threadState
                                  backtraceAddresses:backtrace->addresses
                                     backtraceLength:backtrace->length
                                errorReportingThread:YES
                                               index:threadIndex];
}

#if RSC_HAVE_MACH_THREADS
+ (nullable instancetype)mainThread {
    unsigned threadCount = 0;
    thread_t *threads = rsc_ksmachgetAllThreads(&threadCount);
    if (threads == NULL) {
        return nil;
    }

    struct backtrace_t backtrace;
    NSString *threadState = nil;
    RSCrashReporterThread *object = nil;

    if (threadCount == 0) {
        goto cleanup;
    }

    thread_t thread = threads[0];
    if (MACH_PORT_INDEX(thread) == MACH_PORT_INDEX(rsc_ksmachthread_self())) {
        goto cleanup;
    }

    threadState = thread_state_name(rsc_ksmachgetThreadState(thread));
    BOOL needsResume = thread_suspend(thread) == KERN_SUCCESS;
    backtrace_for_thread(thread, &backtrace);
    if (needsResume) {
        thread_resume(thread);
    }
    object = [[RSCrashReporterThread alloc] initWithMachThread:thread
                                                 state:threadState
                                    backtraceAddresses:backtrace.addresses
                                       backtraceLength:backtrace.length
                                  errorReportingThread:YES
                                                 index:0];

cleanup:
    rsc_ksmachfreeThreads(threads, threadCount);
    return object;
}
#endif

- (instancetype)initWithMachThread:(thread_t)machThread
                             state:(NSString *)state
                backtraceAddresses:(uintptr_t *)backtraceAddresses
                   backtraceLength:(NSUInteger)backtraceLength
              errorReportingThread:(BOOL)errorReportingThread
                             index:(unsigned)index {

    char name[64] = "";
    if (!rsc_ksmachgetThreadName(machThread, name, sizeof(name)) || !name[0]) {
        rsc_ksmachgetThreadQueueName(machThread, name, sizeof(name));
    }

    return [self initWithId:[NSString stringWithFormat:@"%d", index]
                       name:name[0] ? @(name) : nil
       errorReportingThread:errorReportingThread
                       type:RSCThreadTypeCocoa
                      state:state
                 stacktrace:[RSCrashReporterStackframe stackframesWithBacktrace:backtraceAddresses length:backtraceLength]];
}

@end
