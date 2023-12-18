//
// Created by Jamie Lynch on 04/12/2017.
// Copyright (c) 2017 RSCrashReporter. All rights reserved.
//

#import "RSCrashReporterApiClient.h"

#import "RSCJSONSerialization.h"
#import "RSCKeys.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporter.h"
#import "RSCrashReporterConfiguration.h"
#import "RSCrashReporterLogger.h"

#import <CommonCrypto/CommonCrypto.h>

typedef NS_ENUM(NSInteger, HTTPStatusCode) {
    /// 402 Payment Required: a nonstandard client error status response code that is reserved for future use.
    ///
    /// This status code is returned by ngrok when a tunnel has expired.
    HTTPStatusCodePaymentRequired = 402,
    
    /// 407 Proxy Authentication Required: the request has not been applied because it lacks valid authentication credentials
    /// for a proxy server that is between the browser and the server that can access the requested resource.
    HTTPStatusCodeProxyAuthenticationRequired = 407,
    
    /// 408 Request Timeout: the server would like to shut down this unused connection.
    HTTPStatusCodeClientTimeout = 408,
    
    /// 429 Too Many Requests: the user has sent too many requests in a given amount of time ("rate limiting").
    HTTPStatusCodeTooManyRequests = 429,
};

void RSCPostJSONData(NSURLSession *URLSession,
                     NSData *data,
                     NSDictionary<RSCrashReporterHTTPHeaderName, NSString *> *headers,
                     NSURL *url,
                     void (^ completionHandler)(RSCDeliveryStatus status, NSError *_Nullable error)) {
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:RSCIntegrityHeaderValue(data) forHTTPHeaderField:RSCrashReporterHTTPHeaderNameIntegrity];
    [request setValue:[RSC_RFC3339DateTool stringFromDate:[NSDate date]] forHTTPHeaderField:RSCrashReporterHTTPHeaderNameSentAt];
    
    for (RSCrashReporterHTTPHeaderName name in headers) {
        [request setValue:headers[name] forHTTPHeaderField:name];
    }
    
    rsc_log_debug(@"Sending %lu byte payload to %@", (unsigned long)data.length, url);
    
    [[URLSession uploadTaskWithRequest:request fromData:data completionHandler:^(__unused NSData *responseData, NSURLResponse *response, NSError *error) {
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            rsc_log_debug(@"Request to %@ completed with error %@", url, error);
            completionHandler(RSCDeliveryStatusFailed, error ?:
                              [NSError errorWithDomain:@"RSCrashReporterApiClientErrorDomain" code:0 userInfo:@{
                                  NSLocalizedDescriptionKey: @"Request failed: no response was received",
                                  NSURLErrorFailingURLErrorKey: url }]);
            return;
        }
        
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        rsc_log_debug(@"Request to %@ completed with status code %ld", url, (long)statusCode);
        
        if (statusCode / 100 == 2) {
            completionHandler(RSCDeliveryStatusDelivered, nil);
            return;
        }
        
        error = [NSError errorWithDomain:@"RSCrashReporterApiClientErrorDomain" code:1 userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Request failed: unacceptable status code %ld (%@)",
                                        (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]],
            NSURLErrorFailingURLErrorKey: url }];
        
        rsc_log_debug(@"Response headers: %@", ((NSHTTPURLResponse *)response).allHeaderFields);
        rsc_log_debug(@"Response body: %.*s", (int)data.length, (const char *)data.bytes);
        
        if (statusCode / 100 == 4 &&
            statusCode != HTTPStatusCodePaymentRequired &&
            statusCode != HTTPStatusCodeProxyAuthenticationRequired &&
            statusCode != HTTPStatusCodeClientTimeout &&
            statusCode != HTTPStatusCodeTooManyRequests) {
            completionHandler(RSCDeliveryStatusUndeliverable, error);
            return;
        }
        
        completionHandler(RSCDeliveryStatusFailed, error);
    }] resume];
}

NSString * RSCIntegrityHeaderValue(NSData *data) {
    if (!data) {
        return nil;
    }
    unsigned char md[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, md);
    return [NSString stringWithFormat:@"sha1 %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            md[0], md[1], md[2], md[3], md[4],
            md[5], md[6], md[7], md[8], md[9],
            md[10], md[11], md[12], md[13], md[14],
            md[15], md[16], md[17], md[18], md[19]];
}
