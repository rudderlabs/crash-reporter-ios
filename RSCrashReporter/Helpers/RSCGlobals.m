//
//  RSCGlobals.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 18/06/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCGlobals.h"

static dispatch_queue_t rsc_g_fileSystemQueue;

static void RSCGlobalsInit(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rsc_g_fileSystemQueue = dispatch_queue_create("com.bugsnag.filesystem", DISPATCH_QUEUE_SERIAL);
    });
}

dispatch_queue_t RSCGlobalsFileSystemQueue(void) {
    RSCGlobalsInit();
    return rsc_g_fileSystemQueue;
}
