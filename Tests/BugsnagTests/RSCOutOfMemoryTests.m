#import <XCTest/XCTest.h>

#import "RSCFileLocations.h"
#import "RSCRunContext.h"
#import "RSC_KSCrashState.h"
#import "RSC_KSSystemInfo.h"
#import "RSCrashReporter.h"
#import "RSCrashReporterClient+Private.h"
#import "RSCrashReporterConfiguration.h"
#import "RSCrashReporterSystemState.h"
#import "RSCrashReporterTestConstants.h"

@interface RSCOutOfMemoryTests : XCTestCase
@end

@implementation RSCOutOfMemoryTests

- (RSCrashReporterClient *)newClient {
    RSCrashReporterConfiguration *config = [[RSCrashReporterConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
//    config.autoDetectErrors = NO;
    config.releaseStage = @"MagicalTestingTime";

    RSCrashReporterClient *client = [[RSCrashReporterClient alloc] initWithConfiguration:config delegate:nil];
    [client start];
    return client;
}

/**
 * Test that the generated OOM report values exist and are correct (where that can be tested)
 */
- (void)testOOMFieldsSetCorrectly {
    RSCrashReporterClient *client = [self newClient];
    RSCrashReporterSystemState *systemState = [client systemState];

    client.codeBundleId = @"codeBundleIdHere";
    // The update happens on a bg thread, so let it run.
    [NSThread sleepForTimeInterval:0.01f];

    NSDictionary *state = systemState.currentLaunchState;
    XCTAssertNotNil([state objectForKey:@"app"]);
    XCTAssertNotNil([state objectForKey:@"device"]);
    
    NSDictionary *app = [state objectForKey:@"app"];
    XCTAssertNotNil([app objectForKey:@"bundleVersion"]);
    XCTAssertNotNil([app objectForKey:@"id"]);
    XCTAssertNotNil([app objectForKey:@"version"]);
    XCTAssertNotNil([app objectForKey:@"name"]);
    XCTAssertEqualObjects([app valueForKey:@"codeBundleId"], @"codeBundleIdHere");
    XCTAssertEqualObjects([app valueForKey:@"releaseStage"], @"MagicalTestingTime");
    
    NSDictionary *device = [state objectForKey:@"device"];
    XCTAssertNotNil([device objectForKey:@"osName"]);
    XCTAssertNotNil([device objectForKey:@"osBuild"]);
    XCTAssertNotNil([device objectForKey:@"osVersion"]);
    XCTAssertNotNil([device objectForKey:@"id"]);
    XCTAssertNotNil([device objectForKey:@"model"]);
    XCTAssertNotNil([device objectForKey:@"simulator"]);
    XCTAssertNotNil([device objectForKey:@"wordSize"]);
    XCTAssertEqualObjects([device valueForKey:@"locale"], [[NSLocale currentLocale] localeIdentifier]);
}

-(void)testBadJSONData {
    NSString *stateFilePath = [RSCFileLocations current].systemState;
    NSError* error;
    [@"{1=\"a\"" writeToFile:stateFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);

    // Should not crash
    [self newClient];
}

- (void)testLastLaunchTerminatedUnexpectedly {
    if (!rsc_runContext) {
        RSCRunContextInit(RSCFileLocations.current.runContext);
    }
    const struct RSCRunContext *oldContext = rsc_lastRunContext;
    struct RSCRunContext lastRunContext = *rsc_runContext;
    rsc_lastRunContext = &lastRunContext;

    // Debugger active
    
    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = true;
    lastRunContext.isActive = true;
    XCTAssertFalse(RSCRunContextWasKilled());

    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = false;
    lastRunContext.isActive = false;
    XCTAssertFalse(RSCRunContextWasKilled());

    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = true;
    lastRunContext.isActive = true;
    XCTAssertFalse(RSCRunContextWasKilled());

    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = false;
    lastRunContext.isActive = false;
    XCTAssertFalse(RSCRunContextWasKilled());

    // Debugger inactive

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = true;
    lastRunContext.isActive = true;
    XCTAssertFalse(RSCRunContextWasKilled());

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = false;
    lastRunContext.isActive = false;
    XCTAssertFalse(RSCRunContextWasKilled());

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = true;
    lastRunContext.isActive = false;
    XCTAssertFalse(RSCRunContextWasKilled());

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = true;
    lastRunContext.isActive = true;
    XCTAssertTrue(RSCRunContextWasKilled());
    
    uuid_generate(lastRunContext.machoUUID);
    XCTAssertFalse(RSCRunContextWasKilled());
    uuid_copy(lastRunContext.machoUUID, rsc_runContext->machoUUID);
    
    lastRunContext.bootTime = 0;
    XCTAssertFalse(RSCRunContextWasKilled());
    lastRunContext.bootTime = rsc_runContext->bootTime;

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = false;
    lastRunContext.isActive = false;
    XCTAssertFalse(RSCRunContextWasKilled());
    
    rsc_lastRunContext = oldContext;
}

@end
