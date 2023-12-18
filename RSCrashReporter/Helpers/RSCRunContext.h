//
//  RSCRunContext.h
//  RSCrashReporter
//
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#include <dispatch/dispatch.h>
#include <stdbool.h>
#include <stdint.h>
#include <uuid/uuid.h>

#include "RSCDefines.h"

//
// The struct version should be incremented prior to a release if changes have
// been made to RSCRunContext.
//
// During development this is not strictly necessary since last run's data will
// not be loaded if the struct's size has changed.
//
#define RSCRUNCONTEXT_VERSION 4

struct RSCRunContext {
    long structVersion;
    bool isDebuggerAttached;
    bool isLaunching;
    bool isForeground;
    bool isActive;
    bool isTerminating;
    long thermalState;
    uint64_t bootTime;
    uuid_t machoUUID;
    uuid_string_t sessionId;
    double sessionStartTime;
    unsigned long handledCount;
    unsigned long unhandledCount;
#if RSC_HAVE_BATTERY
    float batteryLevel;
    long batteryState;
#endif
#if TARGET_OS_IOS
    long lastKnownOrientation;
#endif
#if RSC_HAVE_OOM_DETECTION
    dispatch_source_memorypressure_flags_t memoryPressure;
#endif
    double timestamp __attribute__((aligned(8)));
    unsigned long long hostMemoryFree;
    unsigned long long memoryAvailable;
    unsigned long long memoryFootprint;
    unsigned long long memoryLimit;
};

/// Information about the current run of the app / process.
///
/// This structure is mapped to a file so that changes will be persisted by the OS.
///
/// Guaranteed to be non-null once RSCRunContextInit() is called.
extern struct RSCRunContext *_Nonnull rsc_runContext;

/// Information about the last run of the app / process, if it could be loaded.
extern const struct RSCRunContext *_Nullable rsc_lastRunContext;

#pragma mark -

#ifdef FOUNDATION_EXTERN
void RSCRunContextInit(NSString *_Nonnull path);
#endif

#pragma mark -

size_t rsc_getHostMemory(void);

void RSCRunContextUpdateMemory(void);

void RSCRunContextUpdateTimestamp(void);

#pragma mark -

#ifdef FOUNDATION_EXTERN
static inline bool RSCRunContextWasCriticalThermalState(void) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    return rsc_lastRunContext && rsc_lastRunContext->thermalState == NSProcessInfoThermalStateCritical;
#pragma clang diagnostic pop
}
#endif

#if !TARGET_OS_WATCH
bool RSCRunContextWasKilled(void);
#endif

static inline bool RSCRunContextWasLaunching(void) {
    return rsc_lastRunContext && rsc_lastRunContext->isLaunching;
}

#if RSC_HAVE_OOM_DETECTION
static inline bool RSCRunContextWasMemoryWarning(void) {
    return rsc_lastRunContext && rsc_lastRunContext->memoryPressure > DISPATCH_MEMORYPRESSURE_NORMAL;
}
#endif

static inline bool RSCRunContextWasTerminating(void) {
    return rsc_lastRunContext && rsc_lastRunContext->isTerminating;
}
