//
//  RSCSessionUploader.h
//  RSCrashReporter
//
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"

@class RSCrashReporterConfiguration;
@class RSCrashReporterNotifier;
@class RSCrashReporterSession;

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCSessionUploader : NSObject

- (instancetype)initWithConfig:(RSCrashReporterConfiguration *)configuration notifier:(RSCrashReporterNotifier *)notifier;

/// Scans previously persisted sessions and either discards or attempts upload.
- (void)processStoredSessions;

- (void)uploadSession:(RSCrashReporterSession *)session;

@property (nonatomic) RSCrashReporterNotifier *notifier;

@end

NS_ASSUME_NONNULL_END
