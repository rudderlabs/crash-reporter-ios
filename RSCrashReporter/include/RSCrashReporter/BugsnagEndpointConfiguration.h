//
//  RSCrashReporterEndpointConfiguration.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 15/04/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Set the endpoints to send data to. By default we'll send error reports to
 * https://notify.bugsnag.com, and sessions to https://sessions.bugsnag.com, but you can
 * override this if you are using RSCrashReporter Enterprise to point to your own RSCrashReporter endpoints.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterEndpointConfiguration : NSObject

/**
 * Configures the endpoint to which events should be sent
 */
@property (copy, nonatomic) NSString *notify;

/**
 * Configures the endpoint to which sessions should be sent
 */
@property (copy, nonatomic) NSString *sessions;

- (instancetype)initWithNotify:(NSString *)notify
                      sessions:(NSString *)sessions;

@end

NS_ASSUME_NONNULL_END
