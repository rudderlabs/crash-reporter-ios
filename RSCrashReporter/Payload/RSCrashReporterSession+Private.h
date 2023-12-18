//
//  RSCrashReporterSession+Private.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 23/11/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import "RSCDefines.h"
#import "RSC_KSCrashReportWriter.h"
#import "RSCrashReporterInternals.h"

NS_ASSUME_NONNULL_BEGIN

@class RSCrashReporterUser;

RSC_OBJC_DIRECT_MEMBERS
@interface RSCrashReporterSession () <NSCopying>

#pragma mark Initializers

- (instancetype)initWithId:(NSString *)sessionId
                 startedAt:(NSDate *)startedAt
                      user:(RSCrashReporterUser *)user
                       app:(RSCrashReporterApp *)app
                    device:(RSCrashReporterDevice *)device;

#pragma mark Properties

@property (getter=isStopped, nonatomic) BOOL stopped;

@property (readwrite, nonnull, nonatomic) RSCrashReporterUser *user;

@end

#pragma mark Serialization

/// Produces a session dictionary that contains all the information to fully recreate it via RSCSessionFromDictionary().
NSDictionary * RSCSessionToDictionary(RSCrashReporterSession *session);

/// Parses a session dictionary produced by RSCSessionToDictionary() or added to a KSCrashReport by BSSerializeDataCrashHandler().
RSCrashReporterSession *_Nullable RSCSessionFromDictionary(NSDictionary *_Nullable json);

/// Produces a session dictionary suitable for inclusion in an event's JSON representation.
NSDictionary * RSCSessionToEventJson(RSCrashReporterSession *session);

/// Parses a session dictionary from an event's JSON representation.
RSCrashReporterSession *_Nullable RSCSessionFromEventJson(NSDictionary *_Nullable json, RSCrashReporterApp *app, RSCrashReporterDevice *device, RSCrashReporterUser *user);

/// Saves the session info into rsc_runContext.
void RSCSessionUpdateRunContext(RSCrashReporterSession *_Nullable session);

/// Returns session information from rsc_lastRunContext.
RSCrashReporterSession *_Nullable RSCSessionFromLastRunContext(RSCrashReporterApp *app, RSCrashReporterDevice *device, RSCrashReporterUser *user);

/// Saves current session information (from rsc_runContext) into a crash report.
void RSCSessionWriteCrashReport(const RSC_KSCrashReportWriter *writer);

/// Returns session information from a crash report previously written to by RSCSessionWriteCrashReport or BSSerializeDataCrashHandler.
RSCrashReporterSession *_Nullable RSCSessionFromCrashReport(NSDictionary *report, RSCrashReporterApp *app, RSCrashReporterDevice *device, RSCrashReporterUser *user);

NS_ASSUME_NONNULL_END
