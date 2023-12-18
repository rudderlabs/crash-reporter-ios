//
//  RSCrashReporterSession.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 RSCrashReporter. All rights reserved.
//

#import "RSCrashReporterSession+Private.h"

#import "RSCKeys.h"
#import "RSCRunContext.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporterApp+Private.h"
#import "RSCrashReporterDevice+Private.h"
#import "RSCrashReporterUser+Private.h"

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterSession

- (instancetype)initWithId:(NSString *)sessionId
                 startedAt:(NSDate *)startedAt
                      user:(RSCrashReporterUser *)user
                       app:(RSCrashReporterApp *)app
                    device:(RSCrashReporterDevice *)device {
    if ((self = [super init])) {
        _id = [sessionId copy];
        _startedAt = startedAt;
        _user = user;
        _app = app;
        _device = device;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    RSCrashReporterSession *session = [[RSCrashReporterSession allocWithZone:zone]
                               initWithId:self.id
                               startedAt:self.startedAt
                               user:self.user
                               app:self.app
                               device:self.device];
    session.handledCount = self.handledCount;
    session.unhandledCount = self.unhandledCount;
    return session;
}

- (void)setUser:(NSString *_Nullable)userId
      withEmail:(NSString *_Nullable)email
        andName:(NSString *_Nullable)name {
    self.user = [[RSCrashReporterUser alloc] initWithId:userId name:name emailAddress:email];
}

@end

#pragma mark - Serialization

NSDictionary * RSCSessionToDictionary(RSCrashReporterSession *session) {
    return @{
        RSCKeyApp: [session.app toDict] ?: @{},
        RSCKeyDevice: [session.device toDictionary] ?: @{},
        RSCKeyHandledCount: @(session.handledCount),
        RSCKeyId: session.id,
        RSCKeyStartedAt: [RSC_RFC3339DateTool stringFromDate:session.startedAt] ?: [NSNull null],
        RSCKeyUnhandledCount: @(session.unhandledCount),
        RSCKeyUser: [session.user toJson] ?: @{}
    };
}

RSCrashReporterSession *_Nullable RSCSessionFromDictionary(NSDictionary *json) {
    NSString *sessionId = json[RSCKeyId];
    NSDate *startedAt = [RSC_RFC3339DateTool dateFromString:json[RSCKeyStartedAt]];
    if (!sessionId || !startedAt) {
        return nil;
    }
    RSCrashReporterApp *app = [RSCrashReporterApp deserializeFromJson:json[RSCKeyApp]];
    RSCrashReporterDevice *device = [RSCrashReporterDevice deserializeFromJson:json[RSCKeyDevice]];
    RSCrashReporterUser *user = [[RSCrashReporterUser alloc] initWithDictionary:json[RSCKeyUser]];
    RSCrashReporterSession *session = [[RSCrashReporterSession alloc] initWithId:sessionId startedAt:startedAt user:user app:app device:device];
    session.handledCount = [json[RSCKeyHandledCount] unsignedIntegerValue];
    session.unhandledCount = [json[RSCKeyUnhandledCount] unsignedIntegerValue];
    return session;
}

NSDictionary * RSCSessionToEventJson(RSCrashReporterSession *session) {
    return @{
        RSCKeyEvents: @{
            RSCKeyHandled: @(session.handledCount),
            RSCKeyUnhandled: @(session.unhandledCount)
        },
        RSCKeyId: session.id,
        RSCKeyStartedAt: [RSC_RFC3339DateTool stringFromDate:session.startedAt] ?: [NSNull null]
    };
}

RSCrashReporterSession * RSCSessionFromEventJson(NSDictionary *_Nullable json, RSCrashReporterApp *app, RSCrashReporterDevice *device, RSCrashReporterUser *user) {
    NSString *sessionId = json[RSCKeyId];
    NSDate *startedAt = [RSC_RFC3339DateTool dateFromString:json[RSCKeyStartedAt]];
    if (!sessionId || !startedAt) {
        return nil;
    }
    RSCrashReporterSession *session = [[RSCrashReporterSession alloc] initWithId:sessionId startedAt:startedAt user:user app:app device:device];
    NSDictionary *events = json[RSCKeyEvents];
    session.handledCount = [events[RSCKeyHandled] unsignedIntegerValue];
    session.unhandledCount = [events[RSCKeyUnhandled] unsignedIntegerValue];
    return session;
}

void RSCSessionUpdateRunContext(RSCrashReporterSession *_Nullable session) {
    if (session) {
        [session.id getCString:rsc_runContext->sessionId maxLength:sizeof(rsc_runContext->sessionId) encoding:NSUTF8StringEncoding];
        rsc_runContext->sessionStartTime = session.startedAt.timeIntervalSinceReferenceDate;
        rsc_runContext->handledCount = session.handledCount;
        rsc_runContext->unhandledCount = session.unhandledCount;
    } else {
        bzero(rsc_runContext->sessionId, sizeof(rsc_runContext->sessionId));
        rsc_runContext->sessionStartTime = 0;
    }
    RSCRunContextUpdateTimestamp();
}

RSCrashReporterSession * RSCSessionFromLastRunContext(RSCrashReporterApp *app, RSCrashReporterDevice *device, RSCrashReporterUser *user) {
    if (rsc_lastRunContext && rsc_lastRunContext->sessionId[0] && rsc_lastRunContext->sessionStartTime > 0) {
        NSString *sessionId = @(rsc_lastRunContext->sessionId);
        NSDate *startedAt = [NSDate dateWithTimeIntervalSinceReferenceDate:rsc_lastRunContext->sessionStartTime];
        RSCrashReporterSession *session = [[RSCrashReporterSession alloc] initWithId:sessionId startedAt:startedAt user:user app:app device:device];
        session.handledCount = rsc_lastRunContext->handledCount;
        session.unhandledCount = rsc_lastRunContext->unhandledCount;
        return session;
    } else {
        return nil;
    }
}

void RSCSessionWriteCrashReport(const RSC_KSCrashReportWriter *writer) {
    if (rsc_runContext->sessionId[0] && rsc_runContext->sessionStartTime > 0) {
        writer->addStringElement(writer, "id", rsc_runContext->sessionId);
        writer->addFloatingPointElement(writer, "startedAt", rsc_runContext->sessionStartTime);
        writer->addUIntegerElement(writer, "handledCount", rsc_runContext->handledCount);
        writer->addUIntegerElement(writer, "unhandledCount", rsc_runContext->unhandledCount + 1);
    }
}

RSCrashReporterSession * RSCSessionFromCrashReport(NSDictionary *report, RSCrashReporterApp *app, RSCrashReporterDevice *device, RSCrashReporterUser *user) {
    NSDictionary *json = report[RSCKeyUser];
    NSString *sessionId = json[RSCKeyId];
    id startedAt = json[RSCKeyStartedAt];
    NSDate *date = nil;
    if ([startedAt isKindOfClass:[NSNumber class]]) {
        date = [NSDate dateWithTimeIntervalSinceReferenceDate:[startedAt doubleValue]];
    } else if ([startedAt isKindOfClass:[NSString class]]) {
        // BSSerializeDataCrashHandler used to store the date as a string
        date = [RSC_RFC3339DateTool dateFromString:startedAt];
    }
    if (!sessionId || !date) {
        return nil;
    }
    RSCrashReporterSession *session = [[RSCrashReporterSession alloc] initWithId:sessionId startedAt:date user:user app:app device:device];
    session.handledCount = [json[RSCKeyHandledCount] unsignedLongValue];
    session.unhandledCount = [json[RSCKeyUnhandledCount] unsignedLongValue];
    return session;
}
