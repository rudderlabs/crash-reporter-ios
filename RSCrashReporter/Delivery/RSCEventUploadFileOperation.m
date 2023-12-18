//
//  RSCEventUploadFileOperation.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCEventUploadFileOperation.h"

#import "RSCFileLocations.h"
#import "RSCJSONSerialization.h"
#import "RSCUtils.h"
#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterInternals.h"
#import "RSCrashReporterLogger.h"


RSC_OBJC_DIRECT_MEMBERS
@implementation RSCEventUploadFileOperation

- (instancetype)initWithFile:(NSString *)file delegate:(id<RSCEventUploadOperationDelegate>)delegate {
    if ((self = [super initWithDelegate:delegate])) {
        _file = [file copy];
    }
    return self;
}

- (RSCrashReporterEvent *)loadEventAndReturnError:(NSError * __autoreleasing *)errorPtr {
    NSDictionary *json = RSCJSONDictionaryFromFile(self.file, 0, errorPtr);
    if (!json) {
        return nil;
    }
    return [[RSCrashReporterEvent alloc] initWithJson:json];
}

- (void)deleteEvent {
    dispatch_sync(RSCGetFileSystemQueue(), ^{
        NSError *error = nil;
        if ([NSFileManager.defaultManager removeItemAtPath:self.file error:&error]) {
            rsc_log_debug(@"Deleted event %@", self.name);
        } else {
            rsc_log_err(@"%@", error);
        }
    });
}

- (void)prepareForRetry:(__unused NSDictionary *)payload HTTPBodySize:(NSUInteger)HTTPBodySize {
    // This event was loaded from disk, so nothing needs to be saved.
    
    // If the payload is oversized or too old, it should be discarded to prevent retrying indefinitely.
    
    if (HTTPBodySize > MaxPersistedSize) {
        rsc_log_debug(@"Deleting oversized event %@", self.name);
        [self deleteEvent];
        return;
    }
    
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.file error:nil];
    if (attributes.fileCreationDate.timeIntervalSinceNow < -MaxPersistedAge) { 
        rsc_log_debug(@"Deleting stale event %@", self.name);
        [self deleteEvent];
        return;
    }
}

- (NSString *)name {
    return self.file.lastPathComponent;
}

@end
