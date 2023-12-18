//
//  RSCEventUploadOperation.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCEventUploadOperation.h"

#import "RSCFileLocations.h"
#import "RSCInternalErrorReporter.h"
#import "RSCJSONSerialization.h"
#import "RSCKeys.h"
#import "RSCrashReporterAppWithState+Private.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterError+Private.h"
#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterInternals.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterNotifier.h"


static NSString * const EventPayloadVersion = @"5.0";

typedef NS_ENUM(NSUInteger, RSCEventUploadOperationState) {
    RSCEventUploadOperationStateReady,
    RSCEventUploadOperationStateExecuting,
    RSCEventUploadOperationStateFinished,
};

@interface RSCEventUploadOperation ()

@property (nonatomic) RSCEventUploadOperationState state;

@end

// MARK: -

@implementation RSCEventUploadOperation

- (instancetype)initWithDelegate:(id<RSCEventUploadOperationDelegate>)delegate {
    if ((self = [super init])) {
        _delegate = delegate;
    }
    return self;
}

- (void)runWithDelegate:(id<RSCEventUploadOperationDelegate>)delegate completionHandler:(nonnull void (^)(void))completionHandler {
    rsc_log_debug(@"Preparing event %@", self.name);
    
    NSError *error = nil;
    RSCrashReporterEvent *event = [self loadEventAndReturnError:&error];
    if (!event) {
        rsc_log_err(@"Failed to load event %@ due to error %@", self.name, error);
        if (!(error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError)) {
            [self deleteEvent];
        }
        completionHandler();
        return;
    }
    
    RSCrashReporterConfiguration *configuration = delegate.configuration;
    
    if (!configuration.shouldSendReports || ![event shouldBeSent]) {
        rsc_log_info(@"Discarding event %@ because releaseStage not in enabledReleaseStages", self.name);
        [self deleteEvent];
        completionHandler();
        return;
    }
    
    NSString *errorClass = event.errors.firstObject.errorClass;
    if ([configuration shouldDiscardErrorClass:errorClass]) {
        rsc_log_info(@"Discarding event %@ because errorClass \"%@\" matches configuration.discardClasses", self.name, errorClass);
        [self deleteEvent];
        completionHandler();
        return;
    }
    
    NSDictionary *retryPayload = nil;
    for (RSCrashReporterOnSendErrorBlock block in configuration.onSendBlocks) {
        @try {
            if (!retryPayload) {
                // If OnSendError modifies the event and delivery fails, we need to persist the original state of the event.
                retryPayload = [event toJsonWithRedactedKeys:configuration.redactedKeys];
            }
            if (!block(event)) {
                [self deleteEvent];
                completionHandler();
                return;
            }
        } @catch (NSException *exception) {
            rsc_log_err(@"Ignoring exception thrown by onSend callback: %@", exception);
        }
    }
    
    NSDictionary *eventPayload;
    @try {
        [event truncateStrings:configuration.maxStringValueLength];
        eventPayload = [event toJsonWithRedactedKeys:configuration.redactedKeys];
        // MARK: - Rudder Commented
        /*if (!retryPayload || [retryPayload isEqualToDictionary:eventPayload]) {
            retryPayload = eventPayload;
        }*/
    } @catch (NSException *exception) {
        rsc_log_err(@"Discarding event %@ due to exception %@", self.name, exception);
        [RSCInternalErrorReporter.sharedInstance reportException:exception diagnostics:nil groupingHash:
         [NSString stringWithFormat:@"RSCEventUploadOperation -[runWithDelegate:completionHandler:] %@ %@",
          exception.name, exception.reason]];
        [self deleteEvent];
        completionHandler();
        return;
    }
    
    NSString *apiKey = event.apiKey ?: configuration.apiKey;
    
    NSMutableDictionary *requestPayload = [NSMutableDictionary dictionary];
    requestPayload[RSCKeyApiKey] = apiKey;
    requestPayload[RSCKeyEvents] = @[eventPayload];
    requestPayload[RSCKeyNotifier] = [delegate.notifier toDict];
    requestPayload[RSCKeyPayloadVersion] = EventPayloadVersion;
    
    // MARK: - Rudder Commented
    /*NSMutableDictionary *requestHeaders = [NSMutableDictionary dictionary];
    requestHeaders[RSCrashReporterHTTPHeaderNameApiKey] = apiKey;
    requestHeaders[RSCrashReporterHTTPHeaderNamePayloadVersion] = EventPayloadVersion;
    requestHeaders[RSCrashReporterHTTPHeaderNameStacktraceTypes] = [event.stacktraceTypes componentsJoinedByString:@","];*/
    
    NSURL *notifyURL = configuration.notifyURL;
    if (!notifyURL) {
        rsc_log_err(@"Could not upload event %@ because notifyURL was nil", self.name);
        completionHandler();
        return;
    }
    
    NSData *data = RSCJSONDataFromDictionary(requestPayload, NULL);
    if (!data) {
        rsc_log_debug(@"Encoding failed; will discard event %@", self.name);
        [self deleteEvent];
        completionHandler();
        return;
    }
    
    if (data.length > MaxPersistedSize) {
        // Trim extra bytes to make space for "removed" message and usage telemetry.
        NSUInteger bytesToRemove = data.length - (MaxPersistedSize - 300);
        rsc_log_debug(@"Trimming breadcrumbs; bytesToRemove = %lu", (unsigned long)bytesToRemove);
        @try {
            [event trimBreadcrumbs:bytesToRemove];
            eventPayload = [event toJsonWithRedactedKeys:configuration.redactedKeys];
            requestPayload[RSCKeyEvents] = @[eventPayload];
            // MARK: - Rudder Commented
            // data = RSCJSONDataFromDictionary(requestPayload, NULL);
        } @catch (NSException *exception) {
            rsc_log_err(@"Discarding event %@ due to exception %@", self.name, exception);
            [RSCInternalErrorReporter.sharedInstance reportException:exception diagnostics:nil groupingHash:
             [NSString stringWithFormat:@"RSCEventUploadOperation -[runWithDelegate:completionHandler:] %@ %@",
              exception.name, exception.reason]];
            [self deleteEvent];
            completionHandler();
            return;
        }
    }
    
    if ([delegate respondsToSelector:@selector(notifyCrashEvent:withRequestPayload:)]) {
        [delegate notifyCrashEvent:event withRequestPayload:requestPayload];
        [self deleteEvent];
    }
    completionHandler();
    
    // MARK: - Rudder Commented
    /*RSCPostJSONData(configuration.sessionOrDefault, data, requestHeaders, notifyURL, ^(RSCDeliveryStatus status, __unused NSError *deliveryError) {
        switch (status) {
            case RSCDeliveryStatusDelivered:
                rsc_log_debug(@"Uploaded event %@", self.name);
                [self deleteEvent];
                break;
                
            case RSCDeliveryStatusFailed:
                rsc_log_debug(@"Upload failed retryably for event %@", self.name);
                [self prepareForRetry:retryPayload HTTPBodySize:data.length];
                break;
                
            case RSCDeliveryStatusUndeliverable:
                rsc_log_debug(@"Upload failed; will discard event %@", self.name);
                [self deleteEvent];
                break;
        }
        
        completionHandler();
    });*/
}

// MARK: Subclassing

- (RSCrashReporterEvent *)loadEventAndReturnError:(__unused NSError * __autoreleasing *)errorPtr {
    // Must be implemented by all subclasses
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)prepareForRetry:(__unused NSDictionary *)payload HTTPBodySize:(__unused NSUInteger)HTTPBodySize {
    // Must be implemented by all subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)deleteEvent {
}

// MARK: Asynchronous NSOperation implementation

- (void)start {
    if ([self isCancelled]) {
        [self setFinished];
        return;
    }
    
    id delegate = self.delegate;
    if (!delegate) {
        rsc_log_err(@"Upload operation %@ has no delegate", self);
        [self setFinished];
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(isExecuting))];
    self.state = RSCEventUploadOperationStateExecuting;
    [self didChangeValueForKey:NSStringFromSelector(@selector(isExecuting))];
    
    @try {
        [self runWithDelegate:delegate completionHandler:^{
            [self setFinished];
        }];
    } @catch (NSException *exception) {
        [RSCInternalErrorReporter.sharedInstance reportException:exception diagnostics:nil groupingHash:
         [NSString stringWithFormat:@"RSCEventUploadOperation -[runWithDelegate:completionHandler:] %@ %@",
          exception.name, exception.reason]];
        [self setFinished];
    }
}

- (void)setFinished {
    if (self.state == RSCEventUploadOperationStateFinished) {
        return;
    }
    [self willChangeValueForKey:NSStringFromSelector(@selector(isExecuting))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(isFinished))];
    self.state = RSCEventUploadOperationStateFinished;
    [self didChangeValueForKey:NSStringFromSelector(@selector(isExecuting))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(isFinished))];
}

- (BOOL)isAsynchronous {
    return YES;
}

- (BOOL)isReady {
    return self.state == RSCEventUploadOperationStateReady;
}

- (BOOL)isExecuting {
    return self.state == RSCEventUploadOperationStateExecuting;
}

- (BOOL)isFinished {
    return self.state == RSCEventUploadOperationStateFinished;
}

@end
