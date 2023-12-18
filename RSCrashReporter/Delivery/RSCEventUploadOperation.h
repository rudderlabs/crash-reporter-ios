//
//  RSCEventUploadOperation.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCrashReporterApiClient.h"

@class RSCrashReporterConfiguration;
@class RSCrashReporterEvent;
@class RSCrashReporterNotifier;

NS_ASSUME_NONNULL_BEGIN

/// Persisted events older than this should be deleted upon failure.
static const NSTimeInterval MaxPersistedAge = 60 * 24 * 60 * 60;

/// Event payloads larger than this should not be persisted.
static const NSUInteger MaxPersistedSize = 1000000;

@protocol RSCEventUploadOperationDelegate;

/**
 * The abstract base class for all event upload operations.
 *
 * Implements an asynchronous NSOperation and the core logic for checking whether an event should be sent, and uploading it.
 */
@interface RSCEventUploadOperation : NSOperation

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDelegate:(id<RSCEventUploadOperationDelegate>)delegate;

@property (readonly, weak, nonatomic) id<RSCEventUploadOperationDelegate> delegate;

// MARK: Subclassing

/// Must be implemented by all subclasses.
- (nullable RSCrashReporterEvent *)loadEventAndReturnError:(NSError **)errorPtr;

/// To be implemented by subclasses that load their data from a file.
- (void)deleteEvent;

/// Must be implemented by all subclasses.
- (void)prepareForRetry:(NSDictionary *)payload HTTPBodySize:(NSUInteger)HTTPBodySize;

@end

// MARK: -

@protocol RSCEventUploadOperationDelegate <NSObject>

@property (readonly, nonatomic) RSCrashReporterConfiguration *configuration;

@property (readonly, nonatomic) RSCrashReporterNotifier *notifier;

- (void)storeEventPayload:(NSDictionary *)eventPayload;

- (void)notifyCrashEvent:(RSCrashReporterEvent *_Nullable)event withRequestPayload:(NSDictionary *_Nullable)requestPayload;

@end

NS_ASSUME_NONNULL_END
