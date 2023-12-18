//
//  RSCInternalErrorReporter.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 06/05/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCInternalErrorReporter.h"

#import "RSCKeys.h"
#import "RSC_KSCrashReportFields.h"
#import "RSC_KSSysCtl.h"
#import "RSC_RFC3339DateTool.h"
#import "RSCrashReporterApiClient.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterError+Private.h"
#import "RSCrashReporterEvent+Private.h"
#import "RSCrashReporterHandledState.h"
#import "RSCrashReporterInternals.h"
#import "RSCrashReporterLogger.h"
#import "RSCrashReporterMetadata+Private.h"
#import "RSCrashReporterNotifier.h"
#import "RSCrashReporterStackframe+Private.h"
#import "RSCrashReporterUser+Private.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#import "RSCUIKit.h"
#elif TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

#import <CommonCrypto/CommonDigest.h>

static NSString * const EventPayloadVersion = @"4.0";

static NSString * const RSCrashReporterDiagnosticsKey = @"RSCrashReporterDiagnostics";

static RSCrashReporterHTTPHeaderName const RSCrashReporterHTTPHeaderNameInternalError = @"RSCrashReporter-Internal-Error";


NSString *RSCErrorDescription(NSError *error) {
    return error ? [NSString stringWithFormat:@"%@ %ld: %@", error.domain, (long)error.code,
                    error.userInfo[NSDebugDescriptionErrorKey] ?: error.localizedDescription] : nil;
}

//static NSString * DeviceId(void);

static NSString * Sysctl(const char *name);


// MARK: -

RSC_OBJC_DIRECT_MEMBERS
@interface RSCInternalErrorReporter ()

@property (nonatomic) NSString *apiKey;
@property (nonatomic) NSURL *endpoint;
@property (nonatomic) NSURLSession *session;

@end


RSC_OBJC_DIRECT_MEMBERS
@implementation RSCInternalErrorReporter

static RSCInternalErrorReporter *sharedInstance_;
static void (^ startupBlock_)(RSCInternalErrorReporter *);

+ (RSCInternalErrorReporter *)sharedInstance {
    return sharedInstance_;
}

+ (void)setSharedInstance:(RSCInternalErrorReporter *)sharedInstance {
    sharedInstance_ = sharedInstance;
    if (startupBlock_ && sharedInstance_) {
        startupBlock_(sharedInstance_);
        startupBlock_ = nil;
    }
}

+ (void)performBlock:(void (^)(RSCInternalErrorReporter *))block {
    if (sharedInstance_) {
        block(sharedInstance_);
    } else {
        startupBlock_ = [block copy];
    }
}

- (instancetype)initWithApiKey:(NSString *)apiKey endpoint:(NSURL *)endpoint {
    if ((self = [super init])) {
        _apiKey = apiKey;
        _endpoint = endpoint;
        _session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    }
    return self;
}

// MARK: Public API

- (void)reportErrorWithClass:(NSString *)errorClass
                     context:(nullable NSString *)context
                     message:(nullable NSString *)message
                 diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics {
    @try {
        RSCrashReporterEvent *event = [self eventWithErrorClass:errorClass context:context message:message diagnostics:diagnostics];
        if (event) {
            [self sendEvent:event];
        }
    } @catch (NSException *exception) {
        rsc_log_err(@"%@", exception);
    }
}

- (void)reportException:(NSException *)exception
            diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics
           groupingHash:(nullable NSString *)groupingHash {
    // MARK: - Rudder Commented
    /*@try {
        RSCrashReporterEvent *event = [self eventWithException:exception diagnostics:diagnostics groupingHash:groupingHash];
        if (event) {
            [self sendEvent:event];
        }
    } @catch (NSException *exception) {
        rsc_log_err(@"%@", exception);
    }*/
}

- (void)reportRecrash:(NSDictionary *)recrashReport {
    @try {
        RSCrashReporterEvent *event = [self eventWithRecrashReport:recrashReport];
        if (event) {
            [self sendEvent:event];
        }
    } @catch (NSException *exception) {
        rsc_log_err(@"%@", exception);
    }
}

// MARK: Private API

- (nullable RSCrashReporterEvent *)eventWithErrorClass:(NSString *)errorClass
                                       context:(nullable NSString *)context
                                       message:(nullable NSString *)message
                                   diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics {
    
    RSCrashReporterError *error =
    [[RSCrashReporterError alloc] initWithErrorClass:errorClass
                                errorMessage:message
                                   errorType:RSCErrorTypeCocoa
                                  stacktrace:nil];
    
    return [self eventWithError:error context:context diagnostics:diagnostics groupingHash:nil];
}

- (nullable RSCrashReporterEvent *)eventWithException:(NSException *)exception
                                  diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics
                                 groupingHash:(nullable NSString *)groupingHash {
    
    NSArray<RSCrashReporterStackframe *> *stacktrace = [RSCrashReporterStackframe stackframesWithCallStackReturnAddresses:exception.callStackReturnAddresses];
    
    RSCrashReporterError *error =
    [[RSCrashReporterError alloc] initWithErrorClass:exception.name
                                errorMessage:exception.reason
                                   errorType:RSCErrorTypeCocoa
                                  stacktrace:stacktrace];
    
    return [self eventWithError:error context:nil diagnostics:diagnostics groupingHash:groupingHash];
}

- (nullable RSCrashReporterEvent *)eventWithRecrashReport:(NSDictionary *)recrashReport {
    NSString *reportType = recrashReport[@ RSC_KSCrashField_Report][@ RSC_KSCrashField_Type];
    if (![reportType isEqualToString:@ RSC_KSCrashReportType_Minimal]) {
        return nil;
    }
    
    NSDictionary *crash = recrashReport[@ RSC_KSCrashField_Crash];
    NSDictionary *crashedThread = crash[@ RSC_KSCrashField_CrashedThread];
    
    NSArray *backtrace = crashedThread[@ RSC_KSCrashField_Backtrace][@ RSC_KSCrashField_Contents];
    NSArray *binaryImages = recrashReport[@ RSC_KSCrashField_BinaryImages];
    NSArray<RSCrashReporterStackframe *> *stacktrace = RSCDeserializeArrayOfObjects(backtrace, ^RSCrashReporterStackframe *(NSDictionary *dict) {
        return [RSCrashReporterStackframe frameFromDict:dict withImages:binaryImages];
    });
    
    NSDictionary *errorDict = crash[@ RSC_KSCrashField_Error];
    RSCrashReporterError *error =
    [[RSCrashReporterError alloc] initWithErrorClass:@"Crash handler crashed"
                                errorMessage:RSCParseErrorClass(errorDict, (id)errorDict[@ RSC_KSCrashField_Type])
                                   errorType:RSCErrorTypeCocoa
                                  stacktrace:stacktrace];
    
    RSCrashReporterEvent *event = [self eventWithError:error context:nil diagnostics:recrashReport groupingHash:nil];
    event.handledState = [RSCrashReporterHandledState handledStateWithSeverityReason:Signal];
    return event;
}

- (nullable RSCrashReporterEvent *)eventWithError:(RSCrashReporterError *)error
                                  context:(nullable NSString *)context
                              diagnostics:(nullable NSDictionary<NSString *, id> *)diagnostics
                             groupingHash:(nullable NSString *)groupingHash {
    
    RSCrashReporterMetadata *metadata = [[RSCrashReporterMetadata alloc] init];
    if (diagnostics) {
        [metadata addMetadata:(NSDictionary * _Nonnull)diagnostics toSection:RSCrashReporterDiagnosticsKey];
    }
    [metadata addMetadata:self.apiKey withKey:RSCKeyApiKey toSection:RSCrashReporterDiagnosticsKey];
    
    NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:
                                   @"/System/Library/CoreServices/SystemVersion.plist"];
    
    RSCrashReporterDeviceWithState *device = [RSCrashReporterDeviceWithState new];
    device.id           = nil; //DeviceId();
    device.manufacturer = @"Apple";
    device.osName       = systemVersion[@"ProductName"];
    device.osVersion    = systemVersion[@"ProductVersion"];
    
#if TARGET_OS_OSX || TARGET_OS_SIMULATOR || (defined(TARGET_OS_MACCATALYST) && TARGET_OS_MACCATALYST)
    device.model        = Sysctl("hw.model");
#else
    device.model        = Sysctl("hw.machine");
    device.modelNumber  = Sysctl("hw.model");
#endif
    
    RSCrashReporterEvent *event =
    [[RSCrashReporterEvent alloc] initWithApp:[RSCrashReporterAppWithState new]
                               device:device
                         handledState:[RSCrashReporterHandledState handledStateWithSeverityReason:HandledError]
                                 user:[[RSCrashReporterUser alloc] init]
                             metadata:metadata
                          breadcrumbs:@[]
                               errors:@[error]
                              threads:@[]
                              session:nil];
    
    event.context = context;
    event.groupingHash = groupingHash;
    
    return event;
}

// MARK: Delivery

- (NSURLRequest *)requestForEvent:(nonnull RSCrashReporterEvent *)event error:(NSError * __autoreleasing *)errorPtr {
    NSMutableDictionary *requestPayload = [NSMutableDictionary dictionary];
    requestPayload[RSCKeyEvents] = @[[event toJsonWithRedactedKeys:nil]];
    requestPayload[RSCKeyNotifier] = [[[RSCrashReporterNotifier alloc] init] toDict];
    requestPayload[RSCKeyPayloadVersion] = EventPayloadVersion;
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:requestPayload options:0 error:errorPtr];
    if (!data) {
        return nil;
    }
    
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    headers[@"Content-Type"] = @"application/json";
    headers[RSCrashReporterHTTPHeaderNameIntegrity] = RSCIntegrityHeaderValue(data);
    headers[RSCrashReporterHTTPHeaderNameInternalError] = @"bugsnag-cocoa";
    headers[RSCrashReporterHTTPHeaderNamePayloadVersion] = EventPayloadVersion;
    headers[RSCrashReporterHTTPHeaderNameSentAt] = [RSC_RFC3339DateTool stringFromDate:[NSDate date]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.endpoint];
    request.allHTTPHeaderFields = headers;
    request.HTTPBody = data;
    request.HTTPMethod = @"POST";
    
    return request;
}

- (void)sendEvent:(nonnull RSCrashReporterEvent *)event {
    // MARK: - Rudder Commented
    /*NSError *error = nil;
    NSURLRequest *request = [self requestForEvent:event error:&error];
    if (!request) {
        rsc_log_err(@"%@", error);
        return;
    }
    [[self.session dataTaskWithRequest:request] resume];*/
}

@end


// MARK: -

// Intentionally differs from +[RSC_KSSystemInfo deviceAndAppHash]
// See ROAD-1488
/*static NSString * DeviceId(void) {
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);

#if TARGET_OS_OSX
    char mac[6] = {0};
    rsc_kssysctl_getMacAddress(RSCKeyDefaultMacName, mac);
    CC_SHA1_Update(&ctx, mac, sizeof(mac));
#elif TARGET_OS_IOS || TARGET_OS_TV
    uuid_t uuid = {0};
    [[[UIDEVICE currentDevice] identifierForVendor] getUUIDBytes:uuid];
    CC_SHA1_Update(&ctx, uuid, sizeof(uuid));
#elif TARGET_OS_WATCH
    uuid_t uuid = {0};
    [[[WKInterfaceDevice currentDevice] identifierForVendor] getUUIDBytes:uuid];
    CC_SHA1_Update(&ctx, uuid, sizeof(uuid));
#else
#error Unsupported target platform
#endif
    
    const char *name = (NSBundle.mainBundle.bundleIdentifier ?: NSProcessInfo.processInfo.processName).UTF8String;
    if (name) {
        CC_SHA1_Update(&ctx, name, (CC_LONG)strlen(name));
    }
    
    unsigned char md[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_Final(md, &ctx);
    
    char hex[2 * sizeof(md)];
    for (size_t i = 0; i < sizeof(md); i++) {
        static char lookup[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
        hex[i * 2 + 0] = lookup[(md[i] & 0xf0) >> 4];
        hex[i * 2 + 1] = lookup[(md[i] & 0x0f)];
    }
    return [[NSString alloc] initWithBytes:hex length:sizeof(hex) encoding:NSASCIIStringEncoding];
}*/

static NSString * Sysctl(const char *name) {
    char buffer[32] = {0};
    if (rsc_kssysctl_stringForName(name, buffer, sizeof buffer - 1)) {
        return @(buffer);
    } else {
        return nil;
    }
}
