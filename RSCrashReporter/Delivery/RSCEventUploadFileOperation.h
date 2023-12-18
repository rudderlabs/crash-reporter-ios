//
//  RSCEventUploadFileOperation.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCEventUploadOperation.h"

#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A concrete operation class for uploading an event that is stored on disk.
 */
RSC_OBJC_DIRECT_MEMBERS
@interface RSCEventUploadFileOperation : RSCEventUploadOperation

- (instancetype)initWithFile:(NSString *)file delegate:(id<RSCEventUploadOperationDelegate>)delegate;

@property (copy, nonatomic) NSString *file;

@end

NS_ASSUME_NONNULL_END
