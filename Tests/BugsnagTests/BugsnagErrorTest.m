//
//  RSCrashReporterErrorTest.m
//  Tests
//
//  Created by Jamie Lynch on 08/04/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSCKeys.h"
#import "RSCrashReporterError+Private.h"
#import "RSCrashReporterStackframe.h"
#import "RSCrashReporterThread+Private.h"

NSString *_Nonnull RSCParseErrorClass(NSDictionary *error, NSString *errorType);

NSString *RSCParseErrorMessage(NSDictionary *report, NSDictionary *error, NSString *errorType);

@interface RSCrashReporterErrorTest : XCTestCase
@property NSDictionary *event;
@end

@implementation RSCrashReporterErrorTest

- (void)setUp {
    NSDictionary *thread = @{
            @"current_thread": @YES,
            @"crashed": @YES,
            @"index": @4,
            @"state": @"TH_STATE_RUNNING",
            @"backtrace": @{
                    @"skipped": @0,
                    @"contents": @[
                            @{
                                    @"symbol_name": @"kscrashsentry_reportUserException",
                                    @"symbol_addr": @4491038467,
                                    @"instruction_addr": @4491038575,
                                    @"object_name": @"CrashProbeiOS",
                                    @"object_addr": @4490747904
                            }
                    ]
            }
    };
    NSDictionary *binaryImage = @{
            @"uuid": @"D0A41830-4FD2-3B02-A23B-0741AD4C7F52",
            @"image_vmaddr": @4294967296,
            @"image_addr": @4490747904,
            @"image_size": @483328,
            @"name": @"/Users/joesmith/foo",
    };
    self.event = @{
            @"crash": @{
                    @"error": @{
                            @"type": @"user",
                            @"user_reported": @{
                                    @"name": @"Foo Exception"
                            },
                            @"reason": @"Foo overload"
                    },
                    @"threads": @[thread],
            },
            @"binary_images": @[binaryImage]
    };
}

- (void)testErrorLoad {
    RSCrashReporterThread *thread = [self findErrorReportingThread:self.event];
    RSCrashReporterError *error = [[RSCrashReporterError alloc] initWithKSCrashReport:self.event stacktrace:thread.stacktrace];
    XCTAssertEqualObjects(@"Foo Exception", error.errorClass);
    XCTAssertEqualObjects(@"Foo overload", error.errorMessage);
    XCTAssertEqual(RSCErrorTypeCocoa, error.type);

    XCTAssertEqual(1, [error.stacktrace count]);
    RSCrashReporterStackframe *frame = error.stacktrace[0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame.method);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame.machoFile);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame.machoUuid);
}

- (void)testErrorFromInvalidJson {
    RSCrashReporterError *error;
    
    error = [RSCrashReporterError errorFromJson:@{
        @"stacktrace": [NSNull null],
    }];
    XCTAssertEqualObjects(error.stacktrace, @[]);
    
    error = [RSCrashReporterError errorFromJson:@{
        @"stacktrace": @{@"foo": @"bar"},
    }];
    XCTAssertEqualObjects(error.stacktrace, @[]);
}

- (void)testToDictionary {
    RSCrashReporterThread *thread = [self findErrorReportingThread:self.event];
    RSCrashReporterError *error = [[RSCrashReporterError alloc] initWithKSCrashReport:self.event stacktrace:thread.stacktrace];
    NSDictionary *dict = [error toDictionary];
    XCTAssertEqualObjects(@"Foo Exception", dict[@"errorClass"]);
    XCTAssertEqualObjects(@"Foo overload", dict[@"message"]);
    XCTAssertEqualObjects(@"cocoa", dict[@"type"]);

    XCTAssertEqual(1, [dict[@"stacktrace"] count]);
    NSDictionary *frame = dict[@"stacktrace"][0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame[@"method"]);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame[@"machoUUID"]);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame[@"machoFile"]);
}

- (RSCrashReporterThread *)findErrorReportingThread:(NSDictionary *)event {
    NSArray *binaryImages = event[@"binary_images"];
    NSArray *threadDict = [event valueForKeyPath:@"crash.threads"];
    NSArray<RSCrashReporterThread *> *threads = [RSCrashReporterThread threadsFromArray:threadDict
                                                           binaryImages:binaryImages];
    for (RSCrashReporterThread *thread in threads) {
        if (thread.errorReportingThread) {
            return thread;
        }
    }
    return nil;
}

- (void)testErrorClassParse {
    XCTAssertEqualObjects(@"foo", RSCParseErrorClass(@{@"cpp_exception": @{@"name": @"foo"}}, @"cpp_exception"));
    XCTAssertEqualObjects(@"bar", RSCParseErrorClass(@{@"mach": @{@"exception_name": @"bar"}}, @"mach"));
    XCTAssertEqualObjects(@"wham", RSCParseErrorClass(@{@"signal": @{@"name": @"wham"}}, @"signal"));
    XCTAssertEqualObjects(@"zed", RSCParseErrorClass(@{@"nsexception": @{@"name": @"zed"}}, @"nsexception"));
    XCTAssertEqualObjects(@"ooh", RSCParseErrorClass(@{@"user_reported": @{@"name": @"ooh"}}, @"user"));
    XCTAssertEqualObjects(@"Exception", RSCParseErrorClass(@{}, @"some-val"));
}

- (void)testErrorMessageParse {
    XCTAssertEqualObjects(@"", RSCParseErrorMessage(@{}, @{}, @""));
    XCTAssertEqualObjects(@"foo", RSCParseErrorMessage(@{}, @{@"reason": @"foo"}, @""));
}

- (void)testStacktraceOverride {
    RSCrashReporterThread *thread = [self findErrorReportingThread:self.event];
    RSCrashReporterError *error = [[RSCrashReporterError alloc] initWithKSCrashReport:self.event stacktrace:thread.stacktrace];
    XCTAssertNotNil(error.stacktrace);
    XCTAssertEqual(1, error.stacktrace.count);
    error.stacktrace = @[];
    XCTAssertEqual(0, error.stacktrace.count);
}

- (void)testUpdateWithCrashInfoMessage {
    RSCrashReporterError *error = [[RSCrashReporterError alloc] initWithErrorClass:@"" errorMessage:@"" errorType:RSCErrorTypeCocoa stacktrace:nil];
    
    // Swift fatal errors with a message.
    // The errorClass and errorMessage should be overwritten with values extracted from the crash info message.
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"Assertion failed: This should NEVER happen: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"Assertion failed");
    XCTAssertEqualObjects(error.errorMessage, @"This should NEVER happen");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"assertion failed: This should NEVER happen: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"assertion failed");
    XCTAssertEqualObjects(error.errorMessage, @"This should NEVER happen");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"Fatal error: A suffusion of yellow: file calc.swift, line 5\n"];
    XCTAssertEqualObjects(error.errorClass, @"Fatal error");
    XCTAssertEqualObjects(error.errorMessage, @"A suffusion of yellow");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"fatal error: This should NEVER happen: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"fatal error");
    XCTAssertEqualObjects(error.errorMessage, @"This should NEVER happen");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"Fatal error: Unexpectedly found nil while unwrapping an Optional value\n"];
    XCTAssertEqualObjects(error.errorClass, @"Fatal error");
    XCTAssertEqualObjects(error.errorMessage, @"Unexpectedly found nil while unwrapping an Optional value");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"Precondition failed:   : strange formatting 😱::: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"Precondition failed");
    XCTAssertEqualObjects(error.errorMessage, @"  : strange formatting 😱::");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"precondition failed:   : strange formatting 😱::: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"precondition failed");
    XCTAssertEqualObjects(error.errorMessage, @"  : strange formatting 😱::");
    
    // Swift fatal errors without a message.
    // The errorClass should be overwritten but the errorMessage left as-is.
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"Assertion failed: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"Assertion failed");
    XCTAssertEqualObjects(error.errorMessage, nil);
    
    error.errorClass = nil;
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"Assertion failed: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"Assertion failed");
    XCTAssertEqualObjects(error.errorMessage, @"Expected message");
    
    error.errorClass = nil;
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"Fatal error: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"Fatal error");
    XCTAssertEqualObjects(error.errorMessage, @"Expected message");
    
    error.errorClass = nil;
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"Precondition failed: file bugsnag_example/AnotherClass.swift, line 24\n"];
    XCTAssertEqualObjects(error.errorClass, @"Precondition failed");
    XCTAssertEqualObjects(error.errorMessage, @"Expected message");
    
    // Non-matching crash info messages.
    // The errorClass should not be overwritten, the errorMessage should be overwritten if it was previously empty / nil.
    
    error.errorClass = nil;
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"Assertion failed: This should NEVER happen: file bugsnag_example/AnotherClass.swift, line 24\njunk"];
    XCTAssertEqualObjects(error.errorClass, nil,);
    XCTAssertEqualObjects(error.errorMessage, @"Expected message");
    
    error.errorClass = @"Expected error class";
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread"];
    XCTAssertEqualObjects(error.errorClass, @"Expected error class");
    
    error.errorClass = @"Expected error class";
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread"];
    XCTAssertEqualObjects(error.errorClass, @"Expected error class",);
    XCTAssertEqualObjects(error.errorMessage, @"BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread");
    
    error.errorClass = @"Expected error class";
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@""];
    XCTAssertEqualObjects(error.errorClass, @"Expected error class");
    XCTAssertEqualObjects(error.errorMessage, @"Expected message",);
    
    error.errorClass = @"Expected error class";
    error.errorMessage = @"Expected message";
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [error updateWithCrashInfoMessage:nil];
#pragma clang diagnostic pop
    XCTAssertEqualObjects(error.errorClass, @"Expected error class",);
    XCTAssertEqualObjects(error.errorMessage, @"Expected message",);
}

- (void)testUpdateWithCrashInfoMessage_Swift54 {
    RSCrashReporterError *error = [[RSCrashReporterError alloc] initWithErrorClass:@"" errorMessage:@"" errorType:RSCErrorTypeCocoa stacktrace:nil];
    
    // Swift fatal errors with a message.
    // The errorClass and errorMessage should be overwritten with values extracted from the crash info message.
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"bugsnag_example/AnotherClass.swift:24: Assertion failed: This should NEVER happen\n"];
    XCTAssertEqualObjects(error.errorClass, @"Assertion failed");
    XCTAssertEqualObjects(error.errorMessage, @"This should NEVER happen");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"calc.swift:5: Fatal error: A suffusion of yellow\n"];
    XCTAssertEqualObjects(error.errorClass, @"Fatal error");
    XCTAssertEqualObjects(error.errorMessage, @"A suffusion of yellow");
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"bugsnag_example/AnotherClass.swift:24: Precondition failed:   : strange formatting 😱::\n"];
    XCTAssertEqualObjects(error.errorClass, @"Precondition failed");
    XCTAssertEqualObjects(error.errorMessage, @"  : strange formatting 😱::");
    
    // Swift fatal errors without a message.
    // The errorClass should be overwritten but the errorMessage left as-is.
    
    error.errorClass = nil;
    error.errorMessage = nil;
    [error updateWithCrashInfoMessage:@"bugsnag_example/AnotherClass.swift:24: Assertion failed\n"];
    XCTAssertEqualObjects(error.errorClass, @"Assertion failed");
    XCTAssertEqualObjects(error.errorMessage, nil);
    
    error.errorClass = nil;
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"bugsnag_example/AnotherClass.swift:24: Assertion failed\n"];
    XCTAssertEqualObjects(error.errorClass, @"Assertion failed");
    XCTAssertEqualObjects(error.errorMessage, @"Expected message");
    
    error.errorClass = nil;
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"bugsnag_example/AnotherClass.swift:24: Fatal error\n"];
    XCTAssertEqualObjects(error.errorClass, @"Fatal error");
    XCTAssertEqualObjects(error.errorMessage, @"Expected message");
    
    error.errorClass = nil;
    error.errorMessage = @"Expected message";
    [error updateWithCrashInfoMessage:@"bugsnag_example/AnotherClass.swift:24: Precondition failed\n"];
    XCTAssertEqualObjects(error.errorClass, @"Precondition failed");
    XCTAssertEqualObjects(error.errorMessage, @"Expected message");
}

@end
