//
//  RSCrashReporterSession.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 RSCrashReporter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterApp.h>
#import <RSCrashReporter/RSCrashReporterDefines.h>
#import <RSCrashReporter/RSCrashReporterDevice.h>
#import <RSCrashReporter/RSCrashReporterUser.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a session of user interaction with your app.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterSession : NSObject

@property (copy, nonatomic) NSString *id;

@property (strong, nonatomic) NSDate *startedAt;

@property (readonly, nonatomic) RSCrashReporterApp *app;

@property (readonly, nonatomic) RSCrashReporterDevice *device;

// =============================================================================
// MARK: - User
// =============================================================================

/**
 * The current user
 */
@property (readonly, nonnull, nonatomic) RSCrashReporterUser *user;

/**
 *  Set user metadata
 *
 *  @param userId ID of the user
 *  @param name   Name of the user
 *  @param email  Email address of the user
 */
- (void)setUser:(nullable NSString *)userId withEmail:(nullable NSString *)email andName:(nullable NSString *)name;

@end

NS_ASSUME_NONNULL_END
