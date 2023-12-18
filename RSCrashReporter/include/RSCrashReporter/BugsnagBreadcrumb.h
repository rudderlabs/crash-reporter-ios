//
//  RSCrashReporterBreadcrumb.h
//
//  Created by Delisa Mason on 9/16/15.
//
//  Copyright (c) 2015 RSCrashReporter, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>

/**
 * Types of breadcrumbs
 */
typedef NS_ENUM(NSUInteger, RSCBreadcrumbType) {
    /**
     *  Any breadcrumb sent via RSCrashReporter.leaveBreadcrumb()
     */
    RSCBreadcrumbTypeManual,
    /**
     *  A call to RSCrashReporter.notify() (internal use only)
     */
    RSCBreadcrumbTypeError,
    /**
     *  A log message
     */
    RSCBreadcrumbTypeLog,
    /**
     *  A navigation action, such as pushing a view controller or dismissing an alert
     */
    RSCBreadcrumbTypeNavigation,
    /**
     *  A background process, such performing a database query
     */
    RSCBreadcrumbTypeProcess,
    /**
     *  A network request
     */
    RSCBreadcrumbTypeRequest,
    /**
     *  Change in application or view state
     */
    RSCBreadcrumbTypeState,
    /**
     *  A user event, such as authentication or control events
     */
    RSCBreadcrumbTypeUser,
};

/**
 * Types of breadcrumbs which can be reported
 */
typedef NS_OPTIONS(NSUInteger, RSCEnabledBreadcrumbType) {
    RSCEnabledBreadcrumbTypeNone       = 0,
    RSCEnabledBreadcrumbTypeState      = 1 << 1,
    RSCEnabledBreadcrumbTypeUser       = 1 << 2,
    RSCEnabledBreadcrumbTypeLog        = 1 << 3,
    RSCEnabledBreadcrumbTypeNavigation = 1 << 4,
    RSCEnabledBreadcrumbTypeRequest    = 1 << 5,
    RSCEnabledBreadcrumbTypeProcess    = 1 << 6,
    RSCEnabledBreadcrumbTypeError      = 1 << 7,
    RSCEnabledBreadcrumbTypeAll = RSCEnabledBreadcrumbTypeState
                                | RSCEnabledBreadcrumbTypeUser
                                | RSCEnabledBreadcrumbTypeLog
                                | RSCEnabledBreadcrumbTypeNavigation
                                | RSCEnabledBreadcrumbTypeRequest
                                | RSCEnabledBreadcrumbTypeProcess
                                | RSCEnabledBreadcrumbTypeError,
};

/**
 * A short log message, representing an action that occurred in your app, to aid with debugging.
 */
@class RSCrashReporterBreadcrumb;

RSCRASHREPORTER_EXTERN
@interface RSCrashReporterBreadcrumb : NSObject

/**
 * The date when the breadcrumb was left
 */
@property (readonly, nullable, nonatomic) NSDate *timestamp;

/**
 * The type of breadcrumb
 */
@property (readwrite, nonatomic) RSCBreadcrumbType type;

/**
 * The description of the breadcrumb
 */
@property (readwrite, copy, nonnull, nonatomic) NSString *message;

/**
 * Diagnostic data relating to the breadcrumb.
 * 
 * The dictionary should be a valid JSON object.
 */
@property (readwrite, copy, nonnull, nonatomic) NSDictionary *metadata;

@end

#pragma mark -

/// Internal protocol, not for public use.
/// Will be removed from public headers in next major release.
/// :nodoc:
@protocol RSCBreadcrumbSink <NSObject>

- (void)leaveBreadcrumbWithMessage:(nonnull NSString *)message metadata:(nullable NSDictionary *)metadata andType:(RSCBreadcrumbType)type
NS_SWIFT_NAME(leaveBreadcrumb(_:metadata:type:));

@end
