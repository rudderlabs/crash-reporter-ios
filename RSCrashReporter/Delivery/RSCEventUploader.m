//
//  RSCEventUploader.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "RSCEventUploader.h"

#import "RSCEventUploadKSCrashReportOperation.h"
#import "RSCEventUploadObjectOperation.h"
#import "RSCFileLocations.h"
#import "RSCInternalErrorReporter.h"
#import "RSCJSONSerialization.h"
#import "RSCUtils.h"
#import "RSCrashReporterConfiguration.h"
#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterInternals.h"
#import "RSCrashReporterLogger.h"


static NSString * const CrashReportPrefix = @"CrashReport-";
static NSString * const RecrashReportPrefix = @"RecrashReport-";


@interface RSCEventUploader () <RSCEventUploadOperationDelegate>

@property (readonly, nonatomic) NSString *eventsDirectory;

@property (readonly, nonatomic) NSString *kscrashReportsDirectory;

@property (readonly, nonatomic) NSOperationQueue *scanQueue;

@property (readonly, nonatomic) NSOperationQueue *uploadQueue;

@property (nonatomic, weak) id<RSCrashReporterNotifyDelegate> delegate;

@end


// MARK: -

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCEventUploader

@synthesize configuration = _configuration;
@synthesize notifier = _notifier;

- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)configuration notifier:(RSCrashReporterNotifier *)notifier delegate:(id<RSCrashReporterNotifyDelegate> _Nullable) delegate {
    if ((self = [super init])) {
        _configuration = configuration;
        _delegate = delegate;
        _eventsDirectory = [RSCFileLocations current].events;
        _kscrashReportsDirectory = [RSCFileLocations current].kscrashReports;
        _notifier = notifier;
        _scanQueue = [[NSOperationQueue alloc] init];
        _scanQueue.maxConcurrentOperationCount = 1;
        _scanQueue.name = @"com.bugsnag.event-scanner";
        _uploadQueue = [[NSOperationQueue alloc] init];
        _uploadQueue.maxConcurrentOperationCount = 1;
        _uploadQueue.name = @"com.bugsnag.event-uploader";
    }
    return self;
}

- (void)dealloc {
    [_scanQueue cancelAllOperations];
    [_uploadQueue cancelAllOperations];
}

// MARK: - Public API

- (void)storeEvent:(RSCrashReporterEvent *)event {
    [event symbolicateIfNeeded];
    [self storeEventPayload:[event toJsonWithRedactedKeys:self.configuration.redactedKeys]];
}

- (void)uploadEvent:(RSCrashReporterEvent *)event completionHandler:(nullable void (^)(void))completionHandler {
    NSUInteger operationCount = self.uploadQueue.operationCount;
    if (operationCount >= self.configuration.maxPersistedEvents) {
        rsc_log_warn(@"Dropping notification, %lu outstanding requests", (unsigned long)operationCount);
        if (completionHandler) {
            completionHandler();
        }
        return;
    }
    RSCEventUploadObjectOperation *operation = [[RSCEventUploadObjectOperation alloc] initWithEvent:event delegate:self];
    operation.completionBlock = completionHandler;
    [self.uploadQueue addOperation:operation];
}

- (void)uploadKSCrashReportWithFile:(NSString *)file completionHandler:(nullable void (^)(void))completionHandler {
    RSCEventUploadKSCrashReportOperation *operation = [[RSCEventUploadKSCrashReportOperation alloc] initWithFile:file delegate:self];
    operation.completionBlock = completionHandler;
    [self.uploadQueue addOperation:operation];
}

- (void)uploadStoredEvents {
    if (self.scanQueue.operationCount > 1) {
        // Prevent too many scan operations being scheduled
        return;
    }
    rsc_log_debug(@"Will scan stored events");
    [self.scanQueue addOperationWithBlock:^{
        [self processRecrashReports];
        NSMutableArray<NSString *> *sortedFiles = [self sortedEventFiles];
        [self deleteExcessFiles:sortedFiles];
        NSArray<RSCEventUploadFileOperation *> *operations = [self uploadOperationsWithFiles:sortedFiles];
        rsc_log_debug(@"Uploading %lu stored events", (unsigned long)operations.count);
        [self.uploadQueue addOperations:operations waitUntilFinished:NO];
    }];
}

- (void)uploadStoredEventsAfterDelay:(NSTimeInterval)delay {
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), queue, ^{
        [self uploadStoredEvents];
    });
}

- (void)uploadLatestStoredEvent:(void (^)(void))completionHandler {
    [self processRecrashReports];
    NSString *latestFile = [self sortedEventFiles].lastObject;
    RSCEventUploadFileOperation *operation = latestFile ? [self uploadOperationsWithFiles:@[latestFile]].lastObject : nil;
    if (!operation) {
        rsc_log_warn(@"Could not find a stored event to upload");
        completionHandler();
        return;
    }
    operation.completionBlock = completionHandler;
    [self.uploadQueue addOperation:operation];
}

// MARK: - Implementation

- (void)processRecrashReports {
    NSError *error = nil;
    NSString *directory = self.kscrashReportsDirectory;
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:directory error:&error];
    if (!entries) {
        rsc_log_err(@"%@", error);
        return;
    }
    
    // Limit to reporting a single recrash to prevent potential for consuming too many resources
    BOOL didReportRecrash = NO;
    
    for (NSString *filename in entries) {
        if (![filename hasPrefix:RecrashReportPrefix] ||
            ![filename.pathExtension isEqual:@"json"]) {
            continue;
        }
        
        NSString *path = [directory stringByAppendingPathComponent:filename];
        if (!didReportRecrash) {
            NSDictionary *recrashReport = RSCJSONDictionaryFromFile(path, 0, &error);
            if (recrashReport) {
                rsc_log_debug(@"Reporting %@", filename);
                [RSCInternalErrorReporter.sharedInstance reportRecrash:recrashReport];
                didReportRecrash = YES;
            }
        }
        rsc_log_debug(@"Deleting %@", filename);
        if (![fileManager removeItemAtPath:path error:&error]) {
            rsc_log_err(@"%@", error);
        }
        
        // Delete the report to prevent reporting a "JSON parsing error"
        NSString *crashReportFilename = [filename stringByReplacingOccurrencesOfString:RecrashReportPrefix withString:CrashReportPrefix];
        NSString *crashReportPath = [directory stringByAppendingPathComponent:crashReportFilename];
        if (!RSCJSONDictionaryFromFile(crashReportPath, 0, nil)) {
            rsc_log_info(@"Deleting unparsable %@", crashReportFilename);
            if (![fileManager removeItemAtPath:crashReportPath error:&error]) {
                rsc_log_err(@"%@", error);
            }
        }
    }
}

/// Returns the stored event files sorted from oldest to most recent.
- (NSMutableArray<NSString *> *)sortedEventFiles {
    NSMutableArray<NSString *> *files = [NSMutableArray array];
    
    NSMutableDictionary<NSString *, NSDate *> *creationDates = [NSMutableDictionary dictionary];
    
    for (NSString *directory in @[self.eventsDirectory, self.kscrashReportsDirectory]) {
        NSError *error = nil;
        NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:&error];
        if (!entries) {
            rsc_log_err(@"%@", error);
            continue;
        }
        
        for (NSString *filename in entries) {
            if (![filename.pathExtension isEqual:@"json"] || [filename hasSuffix:@"-CrashState.json"]) {
                continue;
            }
            
            NSString *file = [directory stringByAppendingPathComponent:filename];
            NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file error:nil];
            creationDates[file] = attributes.fileCreationDate;
            [files addObject:file];
        }
    }
    
    [files sortUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
        NSDate *rhsDate = creationDates[rhs];
        if (!rhsDate) {
            return NSOrderedDescending;
        }
        return [creationDates[lhs] compare:rhsDate];
    }];
    
    return files;
}

/// Deletes the oldest files until no more than `config.maxPersistedEvents` remain and removes them from the array.
- (void)deleteExcessFiles:(NSMutableArray<NSString *> *)sortedEventFiles {
    while (sortedEventFiles.count > self.configuration.maxPersistedEvents) {
        NSString *file = sortedEventFiles[0];
        NSError *error = nil;
        if ([NSFileManager.defaultManager removeItemAtPath:file error:&error]) {
            rsc_log_debug(@"Deleted %@ to comply with maxPersistedEvents", file);
        } else {
            rsc_log_err(@"Error while deleting file: %@", error);
        }
        [sortedEventFiles removeObject:file];
    }
}

/// Creates an upload operation for each file that is not currently being uploaded
- (NSArray<RSCEventUploadFileOperation *> *)uploadOperationsWithFiles:(NSArray<NSString *> *)files {
    NSMutableArray<RSCEventUploadFileOperation *> *operations = [NSMutableArray array];
    
    NSMutableSet<NSString *> *currentFiles = [NSMutableSet set];
    for (id operation in self.uploadQueue.operations) {
        if ([operation isKindOfClass:[RSCEventUploadFileOperation class]]) {
            [currentFiles addObject:((RSCEventUploadFileOperation *)operation).file];
        }
    }
    
    for (NSString *file in files) {
        if ([currentFiles containsObject:file]) {
            continue;
        }
        NSString *directory = file.stringByDeletingLastPathComponent;
        if ([directory isEqualToString:self.kscrashReportsDirectory]) {
            [operations addObject:[[RSCEventUploadKSCrashReportOperation alloc] initWithFile:file delegate:self]];
        } else {
            [operations addObject:[[RSCEventUploadFileOperation alloc] initWithFile:file delegate:self]];
        }
    }
    
    return operations;
}

// MARK: - RSCEventUploadOperationDelegate

- (void)storeEventPayload:(NSDictionary *)eventPayload {
    dispatch_sync(RSCGetFileSystemQueue(), ^{
        NSString *file = [[self.eventsDirectory stringByAppendingPathComponent:[NSUUID UUID].UUIDString] stringByAppendingPathExtension:@"json"];
        NSError *error = nil;
        if (!RSCJSONWriteToFileAtomically(eventPayload, file, &error)) {
            rsc_log_err(@"Error encountered while saving event payload for retry: %@", error);
            return;
        }
        [self deleteExcessFiles:[self sortedEventFiles]];
    });
}

- (void)notifyCrashEvent:(RSCrashReporterEvent *_Nullable)event withRequestPayload:(NSDictionary *_Nullable)requestPayload {
    [self.delegate notifyCrashEvent:event withRequestPayload:requestPayload];
}

@end
