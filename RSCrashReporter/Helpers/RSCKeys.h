//
//  RSCKeys.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 24/10/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSString * RSCKey NS_TYPED_ENUM;

/*
 * These constants are declared with static storage to prevent bloating the
 * symbol and export tables. String pooling means the compiler won't create
 * multiple copies of the same string in the output.
 */

static RSCKey const RSCKeyAction                    = @"action";
static RSCKey const RSCKeyApiKey                    = @"apiKey";
static RSCKey const RSCKeyApp                       = @"app";
static RSCKey const RSCKeyAppType                   = @"appType";
static RSCKey const RSCKeyAppVersion                = @"appVersion";
static RSCKey const RSCKeyAttributes                = @"attributes";
static RSCKey const RSCKeyBatteryLevel              = @"batteryLevel";
static RSCKey const RSCKeyBreadcrumbs               = @"breadcrumbs";
static RSCKey const RSCKeyBundleVersion             = @"bundleVersion";
static RSCKey const RSCKeyCharging                  = @"charging";
static RSCKey const RSCKeyClient                    = @"client";
static RSCKey const RSCKeyCodeBundleId              = @"codeBundleId";
static RSCKey const RSCKeyConfig                    = @"config";
static RSCKey const RSCKeyContext                   = @"context";
static RSCKey const RSCKeyCppException              = @"cpp_exception";
static RSCKey const RSCKeyDevelopment               = @"development";
static RSCKey const RSCKeyDevice                    = @"device";
static RSCKey const RSCKeyEmail                     = @"email";
static RSCKey const RSCKeyEnabledReleaseStages      = @"enabledReleaseStages";
static RSCKey const RSCKeyError                     = @"error";
static RSCKey const RSCKeyErrorClass                = @"errorClass";
static RSCKey const RSCKeyEvents                    = @"events";
static RSCKey const RSCKeyException                 = @"exception";
static RSCKey const RSCKeyExceptionName             = @"exception_name";
static RSCKey const RSCKeyExceptions                = @"exceptions";
static RSCKey const RSCKeyExtraRuntimeInfo          = @"extraRuntimeInfo";
static RSCKey const RSCKeyFeatureFlag               = @"featureFlag";
static RSCKey const RSCKeyFeatureFlags              = @"featureFlags";
static RSCKey const RSCKeyFrameAddress              = @"frameAddress";
static RSCKey const RSCKeyFreeMemory                = @"freeMemory";
static RSCKey const RSCKeyGroupingHash              = @"groupingHash";
static RSCKey const RSCKeyHandled                   = @"handled";
static RSCKey const RSCKeyHandledCount              = @"handledCount";
static RSCKey const RSCKeyId                        = @"id";
static RSCKey const RSCKeyIncomplete                = @"incomplete";
static RSCKey const RSCKeyInfo                      = @"info";
static RSCKey const RSCKeyIsLaunching               = @"isLaunching";
static RSCKey const RSCKeyIsLR                      = @"isLR";
static RSCKey const RSCKeyIsPC                      = @"isPC";
static RSCKey const RSCKeyLabel                     = @"label";
static RSCKey const RSCKeyLogLevel                  = @"logLevel";
static RSCKey const RSCKeyLowMemoryWarning          = @"lowMemoryWarning";
static RSCKey const RSCKeyMach                      = @"mach";
static RSCKey const RSCKeyMachoFile                 = @"machoFile";
static RSCKey const RSCKeyMachoLoadAddr             = @"machoLoadAddress";
static RSCKey const RSCKeyMachoUUID                 = @"machoUUID";
static RSCKey const RSCKeyMachoVMAddress            = @"machoVMAddress";
static RSCKey const RSCKeyMessage                   = @"message";
static RSCKey const RSCKeyMemoryLimit               = @"memoryLimit";
static RSCKey const RSCKeyMemoryUsage               = @"memoryUsage";
static RSCKey const RSCKeyMetadata                  = @"metaData";
static RSCKey const RSCKeyMethod                    = @"method";
static RSCKey const RSCKeyName                      = @"name";
static RSCKey const RSCKeyNotifier                  = @"notifier";
static RSCKey const RSCKeyOrientation               = @"orientation";
static RSCKey const RSCKeyOsVersion                 = @"osVersion";
static RSCKey const RSCKeyPayloadVersion            = @"payloadVersion";
static RSCKey const RSCKeyPersistUser               = @"persistUser";
static RSCKey const RSCKeyProduction                = @"production";
static RSCKey const RSCKeyReason                    = @"reason";
static RSCKey const RSCKeyRedactedKeys              = @"redactedKeys";
static RSCKey const RSCKeyReleaseStage              = @"releaseStage";
static RSCKey const RSCKeySession                   = @"session";
static RSCKey const RSCKeySessions                  = @"sessions";
static RSCKey const RSCKeySeverity                  = @"severity";
static RSCKey const RSCKeySeverityReason            = @"severityReason";
static RSCKey const RSCKeySignal                    = @"signal";
static RSCKey const RSCKeyStacktrace                = @"stacktrace";
static RSCKey const RSCKeyStartedAt                 = @"startedAt";
static RSCKey const RSCKeySymbolAddr                = @"symbolAddress";
static RSCKey const RSCKeySystem                    = @"system";
static RSCKey const RSCKeyThermalState              = @"thermalState";
static RSCKey const RSCKeyThreads                   = @"threads";
static RSCKey const RSCKeyTimestamp                 = @"timestamp";
static RSCKey const RSCKeyType                      = @"type";
static RSCKey const RSCKeyUnhandled                 = @"unhandled";
static RSCKey const RSCKeyUnhandledCount            = @"unhandledCount";
static RSCKey const RSCKeyUnhandledOverridden       = @"unhandledOverridden";
static RSCKey const RSCKeyUrl                       = @"url";
static RSCKey const RSCKeyUsage                     = @"usage";
static RSCKey const RSCKeyUser                      = @"user";
static RSCKey const RSCKeyUuid                      = @"uuid";
static RSCKey const RSCKeyVariant                   = @"variant";
static RSCKey const RSCKeyVersion                   = @"version";
static RSCKey const RSCKeyWarning                   = @"warning";

#define RSCKeyDefaultMacName "en0"
