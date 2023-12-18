//
//  RSCEventUploadObjectOperation.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCEventUploadObjectOperation.h"

#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterInternals.h"
#import "RSCrashReporterLogger.h"

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCEventUploadObjectOperation

- (instancetype)initWithEvent:(RSCrashReporterEvent *)event delegate:(id<RSCEventUploadOperationDelegate>)delegate {
    if ((self = [super initWithDelegate:delegate])) {
        _event = event;
    }
    return self;
}

- (RSCrashReporterEvent *)loadEventAndReturnError:(__unused NSError * __autoreleasing *)errorPtr {
    [self.event symbolicateIfNeeded];
    return self.event;
}

- (void)prepareForRetry:(NSDictionary *)payload HTTPBodySize:(NSUInteger)HTTPBodySize {
    if (HTTPBodySize > MaxPersistedSize) {
        rsc_log_debug(@"Not persisting %@ because HTTP body size (%lu bytes) exceeds MaxPersistedSize",
                      self.name, (unsigned long)HTTPBodySize);
        return;
    }
    [self.delegate storeEventPayload:payload];
}

- (NSString *)name {
    return self.event.description;
}

@end
