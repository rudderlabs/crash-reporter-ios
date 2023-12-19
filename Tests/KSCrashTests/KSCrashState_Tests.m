//
//  rsc_kscrashstate_Tests.m
//
//  Created by Karl Stenerud on 2012-02-05.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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


#import "FileBasedTestCase.h"

#import "RSCRunContext.h"
#import "RSC_KSCrashState.h"
#import "RSC_KSCrashC.h"


@interface rsc_kscrashstate_Tests : FileBasedTestCase
@end


@implementation rsc_kscrashstate_Tests

#if TARGET_OS_OSX || TARGET_OS_TV // Not needed on iOS because there the tests are injected into a host app

- (void)setUp
{
    
    struct RSCRunContext *oldContext = rsc_runContext;
    static struct RSCRunContext context = {0};
    context.isForeground = YES; // These tests assume applicationState == .active
    rsc_runContext = &context;
    [self addTeardownBlock:^{
        rsc_runContext = oldContext;
    }];
    
    [super setUp];
}

#endif

- (void) testInitRelaunch
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

        rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertNotEqual(context.appLaunchTime, 0);

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertFalse(context.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertNotEqual(context.appLaunchTime, 0);

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertFalse(context.crashedLastLaunch, @"");
}

- (void) testInitCrash
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    RSC_KSCrash_State checkpoint0 = context;

    usleep(1);
    rsc_kscrashstate_notifyAppCrash();
    RSC_KSCrash_State checkpointC = context;

    XCTAssertTrue(checkpointC.applicationIsInForeground ==
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpointC.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertGreaterThan(checkpointC.foregroundDurationSinceLaunch,
                         checkpoint0.foregroundDurationSinceLaunch);
    XCTAssertTrue(checkpointC.backgroundDurationSinceLaunch ==
                 checkpoint0.backgroundDurationSinceLaunch, @"");

    XCTAssertTrue(checkpointC.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointC.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertTrue(context.crashedLastLaunch, @"");
}

- (void)testCrashThisLaunch
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                          &context);
    rsc_kscrashstate_notifyAppCrash();
    XCTAssertTrue(context.crashedThisLaunch, @"");
}

- (void)testRelaunch
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    RSC_KSCrash_State checkpoint1 = context;

    XCTAssertFalse(checkpoint1.crashedThisLaunch, @"");
    XCTAssertFalse(checkpoint1.crashedLastLaunch, @"");

    usleep(1);
    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    RSC_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");
    XCTAssertNotEqual(context.appLaunchTime, 0);

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGRelaunch
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    RSC_KSCrash_State checkpoint0 = context;
    NSParameterAssert(context.applicationIsInForeground);

    usleep(1);
    rsc_kscrashstate_notifyAppInForeground(false);
    RSC_KSCrash_State checkpoint1 = context;

    XCTAssertTrue(checkpoint1.applicationIsInForeground !=
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertFalse(checkpoint1.applicationIsInForeground, @"");
    XCTAssertTrue(checkpoint0.appLaunchTime == checkpoint1.appLaunchTime, @"");

    XCTAssertGreaterThan(checkpoint1.foregroundDurationSinceLaunch,
                         checkpoint0.foregroundDurationSinceLaunch);
    XCTAssertTrue(checkpoint1.backgroundDurationSinceLaunch ==
                 checkpoint0.backgroundDurationSinceLaunch, @"");

    XCTAssertFalse(checkpoint1.crashedThisLaunch, @"");
    XCTAssertFalse(checkpoint1.crashedLastLaunch, @"");

    usleep(1);
    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    RSC_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGTerminate
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    NSParameterAssert(context.applicationIsInForeground);
    usleep(1);
    rsc_kscrashstate_notifyAppInForeground(false);
    usleep(1);

    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    RSC_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");
    XCTAssertNotEqual(context.appLaunchTime, 0);

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGCrash
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    usleep(1);
    NSParameterAssert(context.applicationIsInForeground);
    rsc_kscrashstate_notifyAppInForeground(false);
    RSC_KSCrash_State checkpoint0 = context;

    usleep(1);
    rsc_kscrashstate_notifyAppCrash();
    RSC_KSCrash_State checkpointC = context;

    XCTAssertTrue(checkpointC.applicationIsInForeground ==
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpointC.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertTrue(checkpointC.foregroundDurationSinceLaunch ==
                 checkpoint0.foregroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpointC.backgroundDurationSinceLaunch >
                 checkpoint0.backgroundDurationSinceLaunch, @"");

    XCTAssertTrue(checkpointC.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointC.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertTrue(context.crashedLastLaunch, @"");
}

- (void)testBGFGRelaunch
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    usleep(1);
    rsc_kscrashstate_notifyAppInForeground(false);
    usleep(1);
    RSC_KSCrash_State checkpoint0 = context;

    usleep(1);
    rsc_kscrashstate_notifyAppInForeground(true);
    RSC_KSCrash_State checkpoint1 = context;

    XCTAssertTrue(checkpoint1.applicationIsInForeground !=
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpoint1.applicationIsInForeground, @"");
    XCTAssertTrue(checkpoint1.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertTrue(checkpoint1.foregroundDurationSinceLaunch ==
                 checkpoint0.foregroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpoint1.backgroundDurationSinceLaunch >
                 checkpoint0.backgroundDurationSinceLaunch, @"");

    XCTAssertFalse(checkpoint1.crashedThisLaunch, @"");
    XCTAssertFalse(checkpoint1.crashedLastLaunch, @"");

    usleep(1);
    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    RSC_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGFGCrash
{
    RSC_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    usleep(1);
    rsc_kscrashstate_notifyAppInForeground(false);
    usleep(1);
    rsc_kscrashstate_notifyAppInForeground(true);
    RSC_KSCrash_State checkpoint0 = context;

    usleep(1);
    rsc_kscrashstate_notifyAppCrash();
    RSC_KSCrash_State checkpointC = context;

    XCTAssertTrue(checkpointC.applicationIsInForeground ==
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpointC.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertGreaterThan(checkpointC.foregroundDurationSinceLaunch,
                         checkpoint0.foregroundDurationSinceLaunch);
    XCTAssertTrue(checkpointC.backgroundDurationSinceLaunch ==
                 checkpoint0.backgroundDurationSinceLaunch, @"");

    XCTAssertTrue(checkpointC.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointC.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    rsc_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertTrue(context.crashedLastLaunch, @"");
}

- (void)testPersistence
{
    NSString *file = [self.tempPath stringByAppendingPathComponent:@"state.json"];
    
    RSC_KSCrash_State state = {0};
    rsc_kscrashstate_init([file fileSystemRepresentation], &state);
    
    id json = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:file] options:0 error:nil];
    XCTAssertEqualObjects([json objectForKey:@"crashedLastLaunch"], @NO);
    
    rsc_kscrashstate_notifyAppCrash();
    
    json = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:file] options:0 error:nil];
    XCTAssertEqualObjects([json objectForKey:@"crashedLastLaunch"], @YES);
}

@end
