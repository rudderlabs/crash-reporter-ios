//
//  RSCrashReporterBreadcrumbs.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 26/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterBreadcrumbs.h"

#import "RSCFileLocations.h"
#import "RSCJSONSerialization.h"
#import "RSCUtils.h"
#import "RSC_KSCrashReportWriter.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporterBreadcrumb+Private.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterConfiguration+Private.h"
#import "RSCrashReporterLogger.h"

#import <stdatomic.h>

//
// Breadcrumbs are stored as a linked list of JSON encoded C strings
// so that they are accessible at crash time.
//

struct rsc_breadcrumb_list_item {
    struct rsc_breadcrumb_list_item *next;
    char jsonData[]; // MUST be null terminated
};

static _Atomic(struct rsc_breadcrumb_list_item *) g_breadcrumbs_head;
static atomic_bool g_writing_crash_report;

#pragma mark -

@interface RSCrashReporterBreadcrumbs ()

@property (readonly, nonatomic) NSString *breadcrumbsPath;

@property (nonatomic) RSCrashReporterConfiguration *config;
@property (nonatomic) unsigned int nextFileNumber;
@property (nonatomic) unsigned int maxBreadcrumbs;

@end

#pragma mark -

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterBreadcrumbs

- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)config {
    if (!(self = [super init])) {
        return nil;
    }
    
    _config = config;
    // Capture maxBreadcrumbs to protect against config being changed after initialization
    _maxBreadcrumbs = (unsigned int)config.maxBreadcrumbs;
    
    _breadcrumbsPath = [RSCFileLocations current].breadcrumbs;
    
    return self;
}

- (NSArray<RSCrashReporterBreadcrumb *> *)breadcrumbs {
    NSMutableArray<RSCrashReporterBreadcrumb *> *breadcrumbs = [NSMutableArray array];
    @synchronized (self) {
        for (struct rsc_breadcrumb_list_item *item = atomic_load(&g_breadcrumbs_head); item != NULL; item = item->next) {
            NSError *error = nil;
            NSData *data = [NSData dataWithBytesNoCopy:item->jsonData length:strlen(item->jsonData) freeWhenDone:NO];
            NSDictionary *JSONObject = RSCJSONDictionaryFromData(data, 0, &error);
            if (!JSONObject) {
                rsc_log_err(@"Unable to parse breadcrumb: %@", error);
                continue;
            }
            RSCrashReporterBreadcrumb *breadcrumb = [RSCrashReporterBreadcrumb breadcrumbFromDict:JSONObject];
            if (!breadcrumb) {
                rsc_log_err(@"Unexpected breadcrumb payload in buffer");
                continue;
            }
            [breadcrumbs addObject:breadcrumb];
        }
    }
    return breadcrumbs;
}

- (NSArray<RSCrashReporterBreadcrumb *> *)breadcrumbsBeforeDate:(nonnull NSDate *)date {
    // Because breadcrumbs are stored with only millisecond accuracy, we must also round the beforeDate in the same way.
    NSString *dateString = [RSC_RFC3339DateTool stringFromDate:date];
    return RSCArrayMap(self.breadcrumbs, ^id _Nullable(RSCrashReporterBreadcrumb *crumb) {
        // Using `timestampString` is more efficient because `timestamp` is a computed by parsing `timestampString`.
        if ([crumb.timestampString compare:dateString] == NSOrderedDescending) {
            return nil;
        }
        return crumb;
    });
}

- (void)addBreadcrumb:(RSCrashReporterBreadcrumb *)crumb {
    if (self.maxBreadcrumbs == 0) {
        return;
    }
    if (![crumb isValid] || ![self shouldSendBreadcrumb:crumb]) {
        return;
    }
    NSData *data = [self dataForBreadcrumb:crumb];
    if (!data) {
        return;
    }
    [self addBreadcrumbWithData:data writeToDisk:[self shouldWriteToDisk]];
}

- (void)addBreadcrumbWithData:(NSData *)data writeToDisk:(BOOL)writeToDisk {
    struct rsc_breadcrumb_list_item *newItem = calloc(1, sizeof(struct rsc_breadcrumb_list_item) + data.length + 1);
    if (!newItem) {
        return;
    }
    [data getBytes:newItem->jsonData length:data.length];
    
    @synchronized (self) {
        const unsigned int fileNumber = self.nextFileNumber;
        const BOOL deleteOld = fileNumber >= self.maxBreadcrumbs;
        self.nextFileNumber = fileNumber + 1;
        
        struct rsc_breadcrumb_list_item *head = atomic_load(&g_breadcrumbs_head);
        if (head) {
            struct rsc_breadcrumb_list_item *tail = head;
            while (tail->next) {
                tail = tail->next;
            }
            tail->next = newItem;
            if (deleteOld) {
                atomic_store(&g_breadcrumbs_head, head->next);
                while (atomic_load(&g_writing_crash_report)) { continue; }
                free(head);
            }
        } else {
            atomic_store(&g_breadcrumbs_head, newItem);
        }
        
        if (!writeToDisk) {
            return;
        }
        //
        // Breadcrumbs are also stored on disk so that they are accessible at next
        // launch if an OOM is detected.
        //
        dispatch_async(RSCGetFileSystemQueue(), ^{
            // Avoid writing breadcrumbs that have already been deleted from the in-memory store.
            // This can occur when breadcrumbs are being added faster than they can be written.
            BOOL isStale;
            @synchronized (self) {
                unsigned int nextFileNumber = self.nextFileNumber;
                isStale = (self.maxBreadcrumbs < nextFileNumber) && (fileNumber < (nextFileNumber - self.maxBreadcrumbs));
            }
            
            NSError *error = nil;
            
            if (!isStale) {
                NSString *file = [self pathForFileNumber:fileNumber];
                // NSDataWritingAtomic not required because we no longer read the files without checking for validity
                if (![data writeToFile:file options:0 error:&error]) {
                    rsc_log_err(@"Unable to write breadcrumb: %@", error);
                }
            }
            
            if (deleteOld) {
                NSString *fileToDelete = [self pathForFileNumber:fileNumber - self.maxBreadcrumbs];
                if (![[[NSFileManager alloc] init] removeItemAtPath:fileToDelete error:&error] &&
                    !([error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError)) {
                    rsc_log_err(@"Unable to delete old breadcrumb: %@", error);
                }
            }
        });
    }
}

- (BOOL)shouldSendBreadcrumb:(RSCrashReporterBreadcrumb *)crumb {
    for (RSCrashReporterOnBreadcrumbBlock block in self.config.onBreadcrumbBlocks) {
        @try {
            if (!block(crumb)) {
                return NO;
            }
        } @catch (NSException *exception) {
            rsc_log_err(@"Error from onBreadcrumb callback: %@", exception);
        }
    }
    return YES;
}

- (BOOL)shouldWriteToDisk {
#if TARGET_OS_WATCH
    return NO;
#else
    return self.config.enabledErrorTypes.ooms || self.config.enabledErrorTypes.thermalKills;
#endif
}

- (void)removeAllBreadcrumbs {
    @synchronized (self) {
        struct rsc_breadcrumb_list_item *item = atomic_exchange(&g_breadcrumbs_head, NULL);
        while (item) {
            struct rsc_breadcrumb_list_item *next = item->next;
            free(item);
            item = next;
        }
        self.nextFileNumber = 0;
    }
    dispatch_async(RSCGetFileSystemQueue(), ^{
        NSError *error = nil;
        NSString *directory = self.breadcrumbsPath;
        NSFileManager *fileManager = [NSFileManager new];
        if (![fileManager removeItemAtPath:directory error:&error] ||
            ![fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
            rsc_log_debug(@"%s: %@", __FUNCTION__, error);
        }
    });
}

#pragma mark - File storage

- (NSData *)dataForBreadcrumb:(RSCrashReporterBreadcrumb *)breadcrumb {
    NSData *data = nil;
    NSError *error = nil;
    NSDictionary *json = [breadcrumb objectValue];
    if (!json || !(data = RSCJSONDataFromDictionary(json, &error))) {
        rsc_log_err(@"Unable to serialize breadcrumb: %@", error);
    }
    return data;
}

- (NSString *)pathForFileNumber:(unsigned int)fileNumber {
    return [self.breadcrumbsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%u.json", fileNumber]];
}

- (NSArray<RSCrashReporterBreadcrumb *> *)cachedBreadcrumbs {
    NSError *error = nil;
    
    NSArray<NSString *> *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.breadcrumbsPath error:&error];
    if (!filenames) {
        rsc_log_err(@"Unable to read breadcrumbs: %@", error);
        return @[];
    }
    
    // We cannot use NSString's -localizedStandardCompare: because its sorting may vary by locale.
    filenames = [filenames sortedArrayUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2) {
        long long value1 = [[name1 stringByDeletingPathExtension] longLongValue];
        long long value2 = [[name2 stringByDeletingPathExtension] longLongValue];
        if (value1 < value2) { return NSOrderedAscending; }
        if (value1 > value2) { return NSOrderedDescending; }
        return NSOrderedSame;
    }];
    
    NSMutableArray *breadcrumbs = [NSMutableArray array];
    
    for (NSString *file in filenames) {
        if ([file hasPrefix:@"."] || ![file.pathExtension isEqual:@"json"]) {
            // Ignore partially written files, which have names like ".dat.nosync43c9.RZFc3z"
            continue;
        }
        NSString *path = [self.breadcrumbsPath stringByAppendingPathComponent:file];
        NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
        if (!data) {
            // If a high volume of breadcrumbs is being logged, it is normal for older files to be deleted before this thread can read them.
            if (!(error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError)) {
                rsc_log_err(@"Unable to read breadcrumb: %@", error);
            }
            continue;
        }
        NSDictionary *JSONObject = RSCJSONDictionaryFromData(data, 0, &error);
        if (!JSONObject) {
            rsc_log_err(@"Unable to parse breadcrumb: %@", error);
            continue;
        }
        RSCrashReporterBreadcrumb *breadcrumb = [RSCrashReporterBreadcrumb breadcrumbFromDict:JSONObject];
        if (!breadcrumb) {
            rsc_log_err(@"Unexpected breadcrumb payload in file %@", file);
            continue;
        }
        [breadcrumbs addObject:breadcrumb];
    }
    
    return breadcrumbs;
}

@end

#pragma mark -

void RSCrashReporterBreadcrumbsWriteCrashReport(const RSC_KSCrashReportWriter *writer) {
    atomic_store(&g_writing_crash_report, true);
    
    writer->beginArray(writer, "breadcrumbs");
    
    struct rsc_breadcrumb_list_item *item = atomic_load(&g_breadcrumbs_head);
    while (item) {
        writer->addJSONElement(writer, NULL, item->jsonData);
        item = item->next;
    }
    
    writer->endContainer(writer);
    
    atomic_store(&g_writing_crash_report, false);
}
