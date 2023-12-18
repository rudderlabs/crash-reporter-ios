//
//  RSCSessionUploader.m
//  RSCrashReporter
//
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCSessionUploader.h"

#import "RSCFileLocations.h"
#import "RSCJSONSerialization.h"
#import "RSCKeys.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporterApiClient.h"
#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterDevice+Private.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterNotifier.h"
#import "RSCrashReporterSession+Private.h"
#import "RSCrashReporterSession.h"
#import "RSCrashReporterUser+Private.h"

/// Persisted sessions older than this should be deleted without sending.
static const NSTimeInterval MaxPersistedAge = 60 * 24 * 60 * 60;

static NSArray * SortedFiles(NSFileManager *fileManager, NSMutableDictionary<NSString *, NSDate *> **creationDates);


RSC_OBJC_DIRECT_MEMBERS
@interface RSCSessionUploader ()
@property (nonatomic) NSMutableSet *activeIds;
@property(nonatomic) RSCrashReporterConfiguration *config;
@end


RSC_OBJC_DIRECT_MEMBERS
@implementation RSCSessionUploader

- (instancetype)initWithConfig:(RSCrashReporterConfiguration *)config notifier:(RSCrashReporterNotifier *)notifier {
    if ((self = [super init])) {
        _activeIds = [NSMutableSet new];
        _config = config;
        _notifier = notifier;
    }
    return self;
}

- (void)uploadSession:(RSCrashReporterSession *)session {
    [self sendSession:session completionHandler:^(RSCDeliveryStatus status) {
        switch (status) {
            case RSCDeliveryStatusDelivered:
                [self processStoredSessions];
                break;
                
            case RSCDeliveryStatusFailed:
                [self storeSession:session]; // Retry later
                break;
                
            case RSCDeliveryStatusUndeliverable:
                break;
        }
    }];
}

- (void)storeSession:(RSCrashReporterSession *)session {
    NSDictionary *json = RSCSessionToDictionary(session);
    NSString *file = [[RSCFileLocations.current.sessions
                       stringByAppendingPathComponent:session.id]
                      stringByAppendingPathExtension:@"json"];
    
    NSError *error;
    if (RSCJSONWriteToFileAtomically(json, file, &error)) {
        rsc_log_debug(@"Stored session %@", session.id);
        [self pruneFiles];
    } else {
        rsc_log_debug(@"Failed to write session %@", error);
    }
}

- (void)processStoredSessions {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSMutableDictionary<NSString *, NSDate *> *creationDates = nil;
    NSArray *sortedFiles = SortedFiles(fileManager, &creationDates);
    
    for (NSString *file in sortedFiles) {
        if (creationDates[file].timeIntervalSinceNow < -MaxPersistedAge) {
            rsc_log_debug(@"Deleting stale session %@",
                          file.lastPathComponent.stringByDeletingPathExtension);
            [fileManager removeItemAtPath:file error:nil];
            continue;
        }
        
        NSDictionary *json = RSCJSONDictionaryFromFile(file, 0, nil);
        RSCrashReporterSession *session = RSCSessionFromDictionary(json);
        if (!session) {
            rsc_log_debug(@"Deleting invalid session %@",
                          file.lastPathComponent.stringByDeletingPathExtension);
            [fileManager removeItemAtPath:file error:nil];
            continue;
        }
        
        @synchronized (self.activeIds) {
            if ([self.activeIds containsObject:file]) {
                continue;
            }
            [self.activeIds addObject:file];
        }
        
        [self sendSession:session completionHandler:^(RSCDeliveryStatus status) {
            if (status != RSCDeliveryStatusFailed) {
                [fileManager removeItemAtPath:file error:nil];
            }
            @synchronized (self.activeIds) {
                [self.activeIds removeObject:file];
            }
        }];
    }
}

- (void)pruneFiles {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSMutableArray *sortedFiles = [SortedFiles(fileManager, NULL) mutableCopy];
    
    while (sortedFiles.count > self.config.maxPersistedSessions) {
        NSString *file = sortedFiles[0];
        rsc_log_debug(@"Deleting %@ to comply with maxPersistedSessions",
                      file.lastPathComponent.stringByDeletingPathExtension);
        [fileManager removeItemAtPath:file error:nil];
        [sortedFiles removeObject:file];
    }
}

//
// https://bugsnagsessiontrackingapi.docs.apiary.io/#reference/0/session/report-a-session-starting
//
- (void)sendSession:(RSCrashReporterSession *)session completionHandler:(nonnull void (^)(RSCDeliveryStatus status))completionHandler {
    NSString *apiKey = [self.config.apiKey copy];
    if (!apiKey) {
        rsc_log_err(@"Cannot send session because no apiKey is configured.");
        completionHandler(RSCDeliveryStatusUndeliverable);
        return;
    }
    
    NSURL *url = self.config.sessionURL;
    if (!url) {
        rsc_log_err(@"Cannot send session because no endpoint is configured.");
        completionHandler(RSCDeliveryStatusUndeliverable);
        return;
    }
    
    NSDictionary *headers = @{
        RSCrashReporterHTTPHeaderNameApiKey: apiKey,
        RSCrashReporterHTTPHeaderNamePayloadVersion: @"1.0"
    };
    
    NSDictionary *payload = @{
        RSCKeyApp: [session.app toDict] ?: [NSNull null],
        RSCKeyDevice: [session.device toDictionary] ?: [NSNull null],
        RSCKeyNotifier: [self.notifier toDict] ?: [NSNull null],
        RSCKeySessions: @[@{
            RSCKeyId: session.id,
            RSCKeyStartedAt: [RSC_RFC3339DateTool stringFromDate:session.startedAt] ?: [NSNull null],
            RSCKeyUser: [session.user toJson] ?: @{}
        }]
    };
    
    NSData *data = RSCJSONDataFromDictionary(payload, NULL);
    if (!data) {
        rsc_log_err(@"Failed to encode session %@", session.id);
        completionHandler(RSCDeliveryStatusUndeliverable);
        return;
    }
    
    RSCPostJSONData(self.config.sessionOrDefault, data, headers, url, ^(RSCDeliveryStatus status, NSError *error) {
        switch (status) {
            case RSCDeliveryStatusDelivered:
                rsc_log_info(@"Sent session %@", session.id);
                break;
            case RSCDeliveryStatusFailed:
                rsc_log_warn(@"Failed to send sessions: %@", error);
                break;
            case RSCDeliveryStatusUndeliverable:
                rsc_log_warn(@"Failed to send sessions: %@", error);
                break;
        }
        completionHandler(status);
    });
}

@end


static NSArray * SortedFiles(NSFileManager *fileManager, NSMutableDictionary<NSString *, NSDate *> **outDates) {
    NSString *dir = RSCFileLocations.current.sessions;
    NSMutableDictionary<NSString *, NSDate *> *dates = [NSMutableDictionary dictionary];
    
    for (NSString *name in [fileManager contentsOfDirectoryAtPath:dir error:nil]) {
        NSString *file = [dir stringByAppendingPathComponent:name];
        NSDate *date = [fileManager attributesOfItemAtPath:file error:nil].fileCreationDate;
        if (!date) {
            rsc_log_debug(@"Deleting session %@ because fileCreationDate is nil",
                          file.lastPathComponent.stringByDeletingPathExtension);
            [fileManager removeItemAtPath:file error:nil];
        }
        dates[file] = date;
    }
    
    if (outDates) {
        *outDates = dates;
    }
    
    return [dates.allKeys sortedArrayUsingComparator:^(NSString *a, NSString *b) {
        return [dates[a] compare:dates[b] ?: NSDate.distantPast];
    }];
}
