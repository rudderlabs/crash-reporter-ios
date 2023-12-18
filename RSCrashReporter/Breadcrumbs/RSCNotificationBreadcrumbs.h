//
//  RSCNotificationBreadcrumbs.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 10/12/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import <RSCrashReporter/RSCrashReporterBreadcrumb.h>

#import "RSCDefines.h"

@class RSCrashReporterConfiguration;

NS_ASSUME_NONNULL_BEGIN

static NSString * const RSCNotificationBreadcrumbsMessageAppWillTerminate = @"App Will Terminate";

RSC_OBJC_DIRECT_MEMBERS
@interface RSCNotificationBreadcrumbs : NSObject

#pragma mark Initializers

- (instancetype)initWithConfiguration:(RSCrashReporterConfiguration *)configuration
                       breadcrumbSink:(id<RSCBreadcrumbSink>)breadcrumbSink NS_DESIGNATED_INITIALIZER;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

#pragma mark Properties

@property (nonatomic) RSCrashReporterConfiguration *configuration;

@property (weak, nonatomic) id<RSCBreadcrumbSink> breadcrumbSink;

@property (nonatomic) NSNotificationCenter *notificationCenter;

@property (nonatomic) NSNotificationCenter *workspaceNotificationCenter;

#pragma mark Methods

/// Starts observing the default notifications.
- (void)start;

/// Starts observing notifications with the given name and adds a "state" breadcrumbs when received.
- (void)startListeningForStateChangeNotification:(NSNotificationName)notificationName;

- (NSString *)messageForNotificationName:(NSNotificationName)name;

@end

NS_ASSUME_NONNULL_END
