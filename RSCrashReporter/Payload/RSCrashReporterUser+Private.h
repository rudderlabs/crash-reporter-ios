//
//  RSCrashReporterUser+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import "RSCDefines.h"
#import "RSCrashReporterInternals.h"

NS_ASSUME_NONNULL_BEGIN

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterUser ()

- (instancetype)initWithId:(nullable NSString *)id name:(nullable NSString *)name emailAddress:(nullable NSString *)emailAddress;

/// Returns the receiver if it has a non-nil `id`, or a copy of the receiver with a `id` set to `[RSC_KSSystemInfo deviceAndAppHash]`. 
- (RSCrashReporterUser *)withId;

@end

RSCrashReporterUser * RSCGetPersistedUser(void);

void RSCSetPersistedUser(RSCrashReporterUser *_Nullable user);

NS_ASSUME_NONNULL_END
