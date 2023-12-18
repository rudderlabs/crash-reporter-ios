//
//  RSCEventUploadObjectOperation.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCEventUploadOperation.h"

#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A concrete operation class for uploading an event object in memory.
 *
 * If the upload needs to be retried, the event will be persisted to disk.
 */
RSC_OBJC_DIRECT_MEMBERS
@interface RSCEventUploadObjectOperation : RSCEventUploadOperation

- (instancetype)initWithEvent:(RSCrashReporterEvent *)event delegate:(id<RSCEventUploadOperationDelegate>)delegate;

@property (nonatomic) RSCrashReporterEvent *event;

@end

NS_ASSUME_NONNULL_END
