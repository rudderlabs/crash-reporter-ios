//
//  RSCrashReporterBreadcrumbs.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 26/03/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSCDefines.h"

@class RSCrashReporterBreadcrumb;
@class RSCrashReporterConfiguration;
typedef struct RSC_KSCrashReportWriter RSC_KSCrashReportWriter;

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterBreadcrumbs : NSObject

- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)config;

/**
 * Returns an array of new objects representing the breadcrumbs stored in memory.
 */
@property (readonly, nonatomic) NSArray<RSCrashReporterBreadcrumb *> *breadcrumbs;

/**
 * Store a new breadcrumb.
 */
- (void)addBreadcrumb:(RSCrashReporterBreadcrumb *)breadcrumb;

/**
 * Store a new serialized breadcrumb.
 */
- (void)addBreadcrumbWithData:(NSData *)data writeToDisk:(BOOL)writeToDisk;

- (NSArray<RSCrashReporterBreadcrumb *> *)breadcrumbsBeforeDate:(NSDate *)date;

/**
 * The breadcrumb stored on disk.
 */
- (NSArray<RSCrashReporterBreadcrumb *> *)cachedBreadcrumbs;

/**
 * Removes breadcrumbs from disk.
 */
- (void)removeAllBreadcrumbs;

@end

NS_ASSUME_NONNULL_END

#pragma mark -

/**
 * Inserts the current breadcrumbs into a crash report.
 *
 * This function is async-signal-safe, but requires that any threads that could be adding
 * breadcrumbs are suspended.
 */
void RSCrashReporterBreadcrumbsWriteCrashReport(const RSC_KSCrashReportWriter * _Nonnull writer);
