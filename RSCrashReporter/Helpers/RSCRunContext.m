//
//  RSCRunContext.m
//  RSCrashReporter
//
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "RSCRunContext.h"

#import "RSCAppKit.h"
#import "RSCHardware.h"
#import "RSCUIKit.h"
#import "RSCUtils.h"
#import "RSCWatchKit.h"
#import "RSC_KSLogger.h"
#import "RSC_KSMach.h"
#import "RSC_KSMachHeaders.h"
#import "RSC_KSSystemInfo.h"

#import <Foundation/Foundation.h>
#import <stdatomic.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <sys/sysctl.h>

#if __has_include(<os/proc.h>)
#include <os/proc.h>
#endif


// Fields which may be updated from arbitrary threads simultaneously should be
// updated using this macro to avoid data races (which are detected by TSan.)
#define ATOMIC_SET(field, value) do { \
    typeof(field) newValue_ = (value); \
    atomic_store((_Atomic(typeof(field)) *)&field, newValue_); \
} while (0)

#pragma mark Forward declarations

static uint64_t GetBootTime(void);
static bool GetIsActive(void);
static bool GetIsForeground(void);
#if TARGET_OS_IOS || TARGET_OS_TV
static UIApplication * GetUIApplication(void);
#endif
static void InstallTimer(void);


#pragma mark - Initial setup

/// Populates `rsc_runContext`
static void InitRunContext(void) {
    rsc_runContext->isDebuggerAttached = rsc_ksmachisBeingTraced();
    
    rsc_runContext->isLaunching = YES;
    
    // On iOS/tvOS, the app may have launched in the background due to a fetch
    // event or notification (or prewarming on iOS 15+)
    rsc_runContext->isForeground = GetIsForeground();
    
    if (@available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        rsc_runContext->thermalState = NSProcessInfo.processInfo.thermalState;
    }
    
    rsc_runContext->bootTime = GetBootTime();
    
    RSC_Mach_Header_Info *image = rsc_mach_headers_get_main_image();
    if (image && image->uuid) {
        uuid_copy(rsc_runContext->machoUUID, image->uuid);
    }
    
    if ([NSThread isMainThread]) {
        rsc_runContext->isActive = GetIsActive();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            rsc_runContext->isActive = GetIsActive();
        });
    }
    
    RSCRunContextUpdateTimestamp();
    RSCRunContextUpdateMemory();
    if (!rsc_runContext->memoryLimit) {
        rsc_log_debug(@"Cannot query `memoryLimit` on this device");
    }

    InstallTimer();
    
    // Set `structVersion` last so that RSCRunContextLoadLast() will reject data
    // that is not fully initialised.
    rsc_runContext->structVersion = RSCRUNCONTEXT_VERSION;
}

static uint64_t GetBootTime(void) {
    struct timeval tv;
    size_t len = sizeof(tv);
    int ret = sysctl((int[]){CTL_KERN, KERN_BOOTTIME}, 2, &tv, &len, NULL, 0);
    if (ret == -1) return 0;
    return (uint64_t)tv.tv_sec * USEC_PER_SEC + (uint64_t)tv.tv_usec;
}

static bool GetIsActive(void) {
#if TARGET_OS_OSX
    return GetIsForeground();
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
    UIApplication *app = GetUIApplication();
    return app && app.applicationState == UIApplicationStateActive;
#endif

#if TARGET_OS_WATCH
    WKExtension *ext = [WKExtension sharedExtension];
    return ext && ext.applicationState == WKApplicationStateActive;
#endif
}

static bool GetIsForeground(void) {
#if TARGET_OS_OSX
    return [[NSAPPLICATION sharedApplication] isActive];
#endif
    
#if TARGET_OS_IOS
    //
    // Work around unreliability of -[UIApplication applicationState] which
    // always returns UIApplicationStateBackground during the launch of UIScene
    // based apps (until the first scene has been created.)
    //
    task_category_policy_data_t policy;
    mach_msg_type_number_t count = TASK_CATEGORY_POLICY_COUNT;
    boolean_t get_default = FALSE;
    // task_policy_get() is prohibited on tvOS and watchOS
    kern_return_t kr = task_policy_get(mach_task_self(), TASK_CATEGORY_POLICY,
                                       (void *)&policy, &count, &get_default);
    if (kr == KERN_SUCCESS) {
        // TASK_FOREGROUND_APPLICATION  -> normal foreground launch
        // TASK_NONUI_APPLICATION       -> background launch
        // TASK_DARWINBG_APPLICATION    -> iOS 15 prewarming launch
        // TASK_UNSPECIFIED             -> iOS 9 Simulator
        if (!get_default && policy.role == TASK_FOREGROUND_APPLICATION) {
            return true;
        }
    } else {
        rsc_log_err(@"task_policy_get failed: %s", mach_error_string(kr));
    }
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
    UIApplication *application = GetUIApplication();

    // There will be no UIApplication if UIApplicationMain() has not yet been
    // called - e.g. from a SwiftUI app's init() function or UIKit app's main()
    if (!application) {
        return false;
    }

    __block UIApplicationState applicationState;
    if ([[NSThread currentThread] isMainThread]) {
        applicationState = [application applicationState];
    } else {
        // -[UIApplication applicationState] is a main thread-only API
        dispatch_sync(dispatch_get_main_queue(), ^{
            applicationState = [application applicationState];
        });
    }

    return applicationState != UIApplicationStateBackground;
#endif

#if TARGET_OS_WATCH
    WKExtension *ext = [WKExtension sharedExtension];
    return ext && ext.applicationState != WKApplicationStateBackground;
#endif
}

#if TARGET_OS_IOS || TARGET_OS_TV

static UIApplication * GetUIApplication(void) {
    // +sharedApplication is unavailable to app extensions
    if ([RSC_KSSystemInfo isRunningInAppExtension]) {
        return nil;
    }
    // Using performSelector: to avoid a compile-time check that
    // +sharedApplication is not called from app extensions
    return [UIAPPLICATION performSelector:@selector(sharedApplication)];
}

#endif

static void InstallTimer(void) {
    static dispatch_source_t timer;
    
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              /* interval */ NSEC_PER_SEC / 2,
                              /* leeway */   NSEC_PER_SEC / 4);
    
    dispatch_source_set_event_handler(timer, ^{
        RSCRunContextUpdateTimestamp();
        RSCRunContextUpdateMemory();
    });
    
    dispatch_resume(timer);
}


#pragma mark - Observation

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_OSX

static void NoteAppActive(__unused CFNotificationCenterRef center,
                          __unused void *observer,
                          __unused CFNotificationName name,
                          __unused const void *object,
                          __unused CFDictionaryRef userInfo) {
    rsc_runContext->isActive = YES;
    rsc_runContext->isForeground = YES;
    RSCRunContextUpdateTimestamp();
}

static void NoteAppBackground(__unused CFNotificationCenterRef center,
                              __unused void *observer,
                              __unused CFNotificationName name,
                              __unused const void *object,
                              __unused CFDictionaryRef userInfo) {
    rsc_runContext->isActive = NO;
    rsc_runContext->isForeground = NO;
    RSCRunContextUpdateTimestamp();
}

#if !TARGET_OS_OSX
static void NoteAppInactive(__unused CFNotificationCenterRef center,
                            __unused void *observer,
                            __unused CFNotificationName name,
                            __unused const void *object,
                            __unused CFDictionaryRef userInfo) {
    rsc_runContext->isActive = NO;
    rsc_runContext->isForeground = YES;
    RSCRunContextUpdateTimestamp();
}
#endif

static void NoteAppWillTerminate(__unused CFNotificationCenterRef center,
                                 __unused void *observer,
                                 __unused CFNotificationName name,
                                 __unused const void *object,
                                 __unused CFDictionaryRef userInfo) {
    rsc_runContext->isTerminating = YES;
    RSCRunContextUpdateTimestamp();
}

#endif

#if TARGET_OS_IOS

static void NoteBatteryLevel(__unused CFNotificationCenterRef center,
                             __unused void *observer,
                             __unused CFNotificationName name,
                             __unused const void *object,
                             __unused CFDictionaryRef userInfo) {
    rsc_runContext->batteryLevel = RSCGetDevice().batteryLevel;
}

static void NoteBatteryState(__unused CFNotificationCenterRef center,
                             __unused void *observer,
                             __unused CFNotificationName name,
                             __unused const void *object,
                             __unused CFDictionaryRef userInfo) {
    rsc_runContext->batteryState = RSCGetDevice().batteryState;
}

static void NoteOrientation(__unused CFNotificationCenterRef center,
                            __unused void *observer,
                            __unused CFNotificationName name,
                            __unused const void *object,
                            __unused CFDictionaryRef userInfo) {
    UIDeviceOrientation orientation = [UIDEVICE currentDevice].orientation;
    if (orientation != UIDeviceOrientationUnknown) {
        rsc_runContext->lastKnownOrientation = orientation;
    }
    RSCRunContextUpdateTimestamp();
}

#endif

static void NoteThermalState(__unused CFNotificationCenterRef center,
                             __unused void *observer,
                             __unused CFNotificationName name,
                             const void *object,
                             __unused CFDictionaryRef userInfo) {
    if (@available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        // Workaround for iOS 15.0.2 to 15.1.1: Foundation in rare cases posts
        // ThermalStateDidChangeNotification from within -[NSProcessInfo thermalState],
        // causing recursion and a crash via _os_unfair_lock_recursive_abort().
        // To avoid this, grab the new thermal state asynchronously.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            rsc_runContext->thermalState = ((__bridge NSProcessInfo *)object).thermalState;
            RSCRunContextUpdateTimestamp();
        });
    }
}

#if RSC_HAVE_OOM_DETECTION

static void ObserveMemoryPressure(void) {
    // DISPATCH_SOURCE_TYPE_MEMORYPRESSURE arrives slightly sooner than
    // UIApplicationDidReceiveMemoryWarningNotification
    dispatch_source_t source =
    dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
                           DISPATCH_MEMORYPRESSURE_NORMAL |
                           DISPATCH_MEMORYPRESSURE_WARN |
                           DISPATCH_MEMORYPRESSURE_CRITICAL,
                           // Using a high pririty queue to increase chances of
                           // running before OS kills the app.
                           dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
    dispatch_source_set_event_handler(source, ^{
        rsc_runContext->memoryPressure = dispatch_source_get_data(source);
        RSCRunContextUpdateTimestamp();
        RSCRunContextUpdateMemory();
    });
    dispatch_resume(source);
}

#endif

static void AddObservers(void) {
    CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
    
#define OBSERVE(name, function) CFNotificationCenterAddObserver(\
    center, NULL, function, (__bridge CFStringRef)name, NULL, \
    CFNotificationSuspensionBehaviorDeliverImmediately)
    
#if TARGET_OS_IOS || TARGET_OS_TV
    OBSERVE(UIApplicationDidBecomeActiveNotification, NoteAppActive);
    OBSERVE(UIApplicationDidEnterBackgroundNotification, NoteAppBackground);
    OBSERVE(UIApplicationWillEnterForegroundNotification, NoteAppInactive);
    OBSERVE(UIApplicationWillResignActiveNotification, NoteAppInactive);
    OBSERVE(UIApplicationWillTerminateNotification, NoteAppWillTerminate);
#endif
    
#if TARGET_OS_OSX
    OBSERVE(NSApplicationDidBecomeActiveNotification, NoteAppActive);
    OBSERVE(NSApplicationDidResignActiveNotification, NoteAppBackground);
    OBSERVE(NSApplicationWillTerminateNotification, NoteAppWillTerminate);
#endif
    
    if (@available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        OBSERVE(NSProcessInfoThermalStateDidChangeNotification, NoteThermalState);
    }
    
#if RSC_HAVE_BATTERY
    RSCGetDevice().batteryMonitoringEnabled = YES;
    rsc_runContext->batteryLevel = RSCGetDevice().batteryLevel;
    rsc_runContext->batteryState = RSCGetDevice().batteryState;
#endif

#if TARGET_OS_IOS
    UIDevice *currentDevice = [UIDEVICE currentDevice];
    [currentDevice beginGeneratingDeviceOrientationNotifications];
    rsc_runContext->lastKnownOrientation = currentDevice.orientation;
    OBSERVE(UIDeviceOrientationDidChangeNotification, NoteOrientation);
    OBSERVE(UIDeviceBatteryLevelDidChangeNotification, NoteBatteryLevel);
    OBSERVE(UIDeviceBatteryStateDidChangeNotification, NoteBatteryState);
#endif

#if RSC_HAVE_OOM_DETECTION
    ObserveMemoryPressure();
#endif
}


#pragma mark - Misc

void RSCRunContextUpdateTimestamp(void) {
    ATOMIC_SET(rsc_runContext->timestamp, CFAbsoluteTimeGetCurrent());
}

size_t rsc_getHostMemory(void) {
    static _Atomic mach_port_t host_atomic = 0;
    mach_port_t host = atomic_load(&host_atomic);
    if (!host) {
        host = mach_host_self();
        atomic_store(&host_atomic, host);
    }

    vm_statistics_data_t host_vm;
    mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
    kern_return_t kr = host_statistics(host, HOST_VM_INFO,
                                       (host_info_t)&host_vm, &count);
    if (kr != KERN_SUCCESS) {
        rsc_log_debug(@"host_statistics: %d", kr);
        return 0;
    }

    return host_vm.free_count * vm_kernel_page_size;
}

static void UpdateHostMemory(void) {
    size_t hostMemoryFree = rsc_getHostMemory();
    if (hostMemoryFree > 0) {
        ATOMIC_SET(rsc_runContext->hostMemoryFree, hostMemoryFree);
    }
}

void setMemoryUsageRSC(uint64_t footprint, uint64_t available) {
    uint64_t limit = footprint + available;
    ATOMIC_SET(rsc_runContext->memoryAvailable, available);
    ATOMIC_SET(rsc_runContext->memoryLimit, limit);
}

static void UpdateTaskMemory(void) {
    task_vm_info_data_t task_vm = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kr = task_info(current_task(), TASK_VM_INFO,
                                 (task_info_t)&task_vm, &count);
    if (kr != KERN_SUCCESS) {
        rsc_log_debug(@"task_info: %d", kr);
        return;
    }
    
    unsigned long long footprint = task_vm.phys_footprint;
    ATOMIC_SET(rsc_runContext->memoryFootprint, footprint);
    
    // Since limit_bytes_remaining was added in iOS 13 (xnu-6153)
    // this code must be compiled out when building with older SDKs.
#ifdef TASK_VM_INFO_REV4_COUNT
    if (task_vm.limit_bytes_remaining) {
        setMemoryUsageRSC(footprint, task_vm.limit_bytes_remaining);
    } else {
#if !TARGET_OS_OSX
    if (@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
        setMemoryUsageRSC(footprint, os_proc_available_memory());
    }
#endif
    }
#endif
}

void RSCRunContextUpdateMemory(void) {
    UpdateTaskMemory();
    UpdateHostMemory();
}


#pragma mark - Kill detection

#if !TARGET_OS_WATCH

bool RSCRunContextWasKilled(void) {
    // App extensions have a different lifecycle and the heuristic used for
    // finding app terminations rooted in fixable code does not apply
    if ([RSC_KSSystemInfo isRunningInAppExtension]) {
        return NO;
    }
    
    if (!rsc_lastRunContext) {
        return NO;
    }
    
    if (rsc_lastRunContext->isTerminating) {
        return NO; // The app terminated normally
    }
    
    if (rsc_lastRunContext->isDebuggerAttached) {
        return NO; // The debugger may have killed the app
    }
    
    if (rsc_lastRunContext->bootTime != rsc_runContext->bootTime) {
        return NO; // The app may have been terminated due to the reboot
    }
    
    // Ignore unexpected terminations due to the app being upgraded
    if (uuid_compare(rsc_lastRunContext->machoUUID, rsc_runContext->machoUUID)) {
        return NO;
    }
    
    // Once the app is in the background we cannot determine between good (user
    // closed from the app switcher) and bad (OS killed the app) terminations.
    if (!rsc_lastRunContext->isForeground) {
        rsc_log_debug(@"Ignoring kill that occurred while in background");
        return NO;
    }
    
    // PLAT-3259: Do not report OOMs from UIApplicationStateInactive.
    if (!rsc_lastRunContext->isActive) {
        rsc_log_debug(@"Ignoring kill that occurred while inactive");
        return NO;
    }
    
    return YES;
}

#endif


#pragma mark - File handling & memory mapping

#define SIZEOF_STRUCT sizeof(struct RSCRunContext)

static struct RSCRunContext fallback;
struct RSCRunContext *rsc_runContext = &fallback;

const struct RSCRunContext *rsc_lastRunContext;

/// Opens the file and disables content protection, returning -1 on error.
static int OpenFile(NSString *_Nonnull path) {
    int fd = open(path.fileSystemRepresentation, O_RDWR | O_CREAT, 0600);
    if (fd == -1) {
        rsc_log_warn(@"Could not open %@", path);
        return -1;
    }
    
    // NSFileProtectionComplete invalidates mappings 10 seconds after device is
    // locked, so must be disabled to prevent segfaults when accessing 
    // rsc_runContext
    if (!RSCDisableNSFileProtectionComplete(path)) {
        close(fd);
        return -1;
    }
    
    return fd;
}

/// Loads the contents of the state file into memory and sets the
/// `rsc_lastRunContext` pointer if the contents are valid.
static void LoadLastRunContext(int fd) {
    struct stat sb;
    // Only expose previous state if size matches...
    if (fstat(fd, &sb) == 0 && sb.st_size == SIZEOF_STRUCT) {
        static struct RSCRunContext context;
        if (read(fd, &context, SIZEOF_STRUCT) == SIZEOF_STRUCT &&
            // ...and so does the structVersion
            context.structVersion == RSCRUNCONTEXT_VERSION) {
            rsc_lastRunContext = &context;
        }
    }
}

/// Truncates or extends the file to the size of struct RSCRunContext,
/// maps it into memory, and sets the `rsc_runContext` pointer.
static void ResizeAndMapFile(int fd) {
    // Note: ftruncate fills the file with zeros when extending.
    if (ftruncate(fd, SIZEOF_STRUCT) != 0) {
        rsc_log_warn(@"ftruncate failed: %d", errno);
        return;
    }
    
    const int prot = PROT_READ | PROT_WRITE;
    const int flags = MAP_FILE | MAP_SHARED;
    void *ptr = mmap(0, SIZEOF_STRUCT, prot, flags, fd, 0);
    if (ptr == MAP_FAILED) {
        rsc_log_warn(@"mmap failed: %d", errno);
        return;
    }
    
    memset(ptr, 0, SIZEOF_STRUCT);
    mlock(ptr, SIZEOF_STRUCT);
    rsc_runContext = ptr;
}

void RSCRunContextInit(NSString *_Nonnull path) {
    int fd = OpenFile(path);
    LoadLastRunContext(fd);
    ResizeAndMapFile(fd);
    InitRunContext();
    AddObservers();
    if (fd > 0) {
        close(fd);
    }
}
