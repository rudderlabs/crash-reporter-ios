//
// Created by Jamie Lynch on 04/12/2017.
// Copyright (c) 2017 RSCrashReporter. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * RSCrashReporterHTTPHeaderName NS_TYPED_ENUM;

static RSCrashReporterHTTPHeaderName const RSCrashReporterHTTPHeaderNameApiKey             = @"RSCrashReporter-Api-Key";
static RSCrashReporterHTTPHeaderName const RSCrashReporterHTTPHeaderNameIntegrity          = @"RSCrashReporter-Integrity";
static RSCrashReporterHTTPHeaderName const RSCrashReporterHTTPHeaderNamePayloadVersion     = @"RSCrashReporter-Payload-Version";
static RSCrashReporterHTTPHeaderName const RSCrashReporterHTTPHeaderNameSentAt             = @"RSCrashReporter-Sent-At";
static RSCrashReporterHTTPHeaderName const RSCrashReporterHTTPHeaderNameStacktraceTypes    = @"RSCrashReporter-Stacktrace-Types";

typedef NS_ENUM(NSInteger, RSCDeliveryStatus) {
    /// The payload was delivered successfully and can be deleted.
    RSCDeliveryStatusDelivered,
    /// The payload was not delivered but can be retried, e.g. when there was a loss of connectivity.
    RSCDeliveryStatusFailed,
    /// The payload cannot be delivered and should be deleted without attempting to retry.
    RSCDeliveryStatusUndeliverable,
};

void RSCPostJSONData(NSURLSession *URLSession,
                     NSData *data,
                     NSDictionary<RSCrashReporterHTTPHeaderName, NSString *> *headers,
                     NSURL *url,
                     void (^ completionHandler)(RSCDeliveryStatus status, NSError *_Nullable error));

NSString *_Nullable RSCIntegrityHeaderValue(NSData *_Nullable data);

NS_ASSUME_NONNULL_END
