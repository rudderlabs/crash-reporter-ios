//
//  RSCConnectivity.m
//
//  Created by Jamie Lynch on 2017-09-04.
//
//  Copyright (c) 2017 RSCrashReporter, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RSCConnectivity.h"
#import "RSCrashReporter.h"

#if RSC_HAVE_REACHABILITY

static const SCNetworkReachabilityFlags kSCNetworkReachabilityFlagsUninitialized = UINT32_MAX;

static SCNetworkReachabilityRef rsc_reachability_ref;
static RSCConnectivityChangeBlock rsc_reachability_change_block;
static SCNetworkReachabilityFlags rsc_current_reachability_state = kSCNetworkReachabilityFlagsUninitialized;

static NSString *const RSCConnectivityCellular = @"cellular";
static NSString *const RSCConnectivityWiFi = @"wifi";
static NSString *const RSCConnectivityNone = @"none";

/**
 * Check whether the connectivity change should be noted or ignored.
 *
 * @return YES if the connectivity change should be reported
 */
BOOL RSCConnectivityShouldReportChange(SCNetworkReachabilityFlags flags) {
    #if RSC_HAVE_REACHABILITY_WWAN
        // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
        const SCNetworkReachabilityFlags importantFlags = kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable;
    #else
        const SCNetworkReachabilityFlags importantFlags = kSCNetworkReachabilityFlagsReachable;
    #endif
    __block BOOL shouldReport = YES;
    // Check if the reported state is different from the last known state (if any)
    SCNetworkReachabilityFlags newFlags = flags & importantFlags;
    SCNetworkReachabilityFlags oldFlags = rsc_current_reachability_state & importantFlags;
    if (newFlags != oldFlags) {
        // When first subscribing to be notified of changes, the callback is
        // invoked immmediately even if nothing has changed. So this block
        // ignores the very first check, reporting all others.
        if (rsc_current_reachability_state == kSCNetworkReachabilityFlagsUninitialized) {
            shouldReport = NO;
        }
        // Cache the reachability state to report the previous value representation
        rsc_current_reachability_state = flags;
    } else {
        shouldReport = NO;
    }
    return shouldReport;
}

/**
 * Textual representation of a connection type
 */
NSString *RSCConnectivityFlagRepresentation(SCNetworkReachabilityFlags flags) {
    BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    #if RSC_HAVE_REACHABILITY_WWAN
        return connected
            ? ((flags & kSCNetworkReachabilityFlagsIsWWAN) ? RSCConnectivityCellular : RSCConnectivityWiFi)
            : RSCConnectivityNone;
    #else
        return connected ? RSCConnectivityWiFi : RSCConnectivityNone;
    #endif
}

/**
 * Callback invoked by SCNetworkReachability, which calls an Objective-C block
 * that handles the connection change.
 */
void RSCConnectivityCallback(__unused SCNetworkReachabilityRef target,
                             SCNetworkReachabilityFlags flags,
                             __unused void *info)
{
    if (rsc_reachability_change_block && RSCConnectivityShouldReportChange(flags)) {
        BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
        rsc_reachability_change_block(connected, RSCConnectivityFlagRepresentation(flags));
    }
}

@implementation RSCConnectivity

+ (void)monitorURL:(NSURL *)URL usingCallback:(RSCConnectivityChangeBlock)block {
    static dispatch_once_t once_t;
    static dispatch_queue_t reachabilityQueue;
    dispatch_once(&once_t, ^{
        reachabilityQueue = dispatch_queue_create("com.bugsnag.cocoa.connectivity", DISPATCH_QUEUE_SERIAL);
    });

    rsc_reachability_change_block = block;

    const char *nodename = URL.host.UTF8String;
    if (!nodename || ![self isValidHostname:@(nodename)]) {
        return;
    }

    rsc_reachability_ref = SCNetworkReachabilityCreateWithName(NULL, nodename);
    if (rsc_reachability_ref) { // Can be null if a bad hostname was specified
        SCNetworkReachabilitySetCallback(rsc_reachability_ref, RSCConnectivityCallback, NULL);
        SCNetworkReachabilitySetDispatchQueue(rsc_reachability_ref, reachabilityQueue);
    }
}

/**
 * Check if the host is valid and not equivalent to localhost, from which we can
 * never truly disconnect. 🏡
 * There are also system handlers for localhost which we don't want to catch
 * inadvertently.
 */
+ (BOOL)isValidHostname:(NSString *)host {
    return host.length > 0
        && ![host isEqualToString:@"localhost"]
        && ![host isEqualToString:@"::1"]
        && ![host isEqualToString:@"127.0.0.1"];
}

+ (void)stopMonitoring {
    rsc_reachability_change_block = nil;
    if (rsc_reachability_ref) {
        SCNetworkReachabilitySetCallback(rsc_reachability_ref, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(rsc_reachability_ref, NULL);
    }
    rsc_current_reachability_state = kSCNetworkReachabilityFlagsUninitialized;
}

@end

#endif
