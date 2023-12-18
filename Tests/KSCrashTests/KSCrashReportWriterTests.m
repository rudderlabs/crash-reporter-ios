//
//  KSCrashReportWriterTests.m
//  RSCrashReporter
//
//  Created by Nick Dowell on 23/10/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RSC_KSCrashReportWriter.h"
#import "RSC_KSFileUtils.h"
#import "RSC_KSJSONCodec.h"

// Defined in RSC_KSCrashReport.c
void rsc_kscrw_i_prepareReportWriter(RSC_KSCrashReportWriter *const writer, RSC_KSJSONEncodeContext *const context);

static int addJSONData(const char *data, size_t length, NSMutableData *userData) {
    [userData appendBytes:data length:length];
    return RSC_KSJSON_OK;
}

static id JSONObject(void (^ block)(RSC_KSCrashReportWriter *writer)) {
    NSMutableData *data = [NSMutableData data];
    RSC_KSJSONEncodeContext encodeContext;
    RSC_KSCrashReportWriter reportWriter;
    rsc_kscrw_i_prepareReportWriter(&reportWriter, &encodeContext);
    rsc_ksjsonbeginEncode(&encodeContext, false, (RSC_KSJSONAddDataFunc)addJSONData, (__bridge void *)data);
    block(&reportWriter);
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

#pragma mark -

@interface KSCrashReportWriterTests : XCTestCase
@end

#pragma mark -

@implementation KSCrashReportWriterTests

- (void)testSimpleObject {
    id object = JSONObject(^(RSC_KSCrashReportWriter *writer) {
        writer->beginObject(writer, NULL);
        writer->addStringElement(writer, "foo", "bar");
        writer->endContainer(writer);
    });
    XCTAssertEqualObjects(object, @{@"foo": @"bar"});
}

- (void)testArray {
    id object = JSONObject(^(RSC_KSCrashReportWriter *writer) {
        writer->beginArray(writer, NULL);
        writer->addStringElement(writer, "foo", "bar");
        writer->endContainer(writer);
    });
    XCTAssertEqualObjects(object, @[@"bar"]);
}

- (void)testArrayInsideObject {
    id object = JSONObject(^(RSC_KSCrashReportWriter *writer) {
        writer->beginObject(writer, NULL);
        writer->beginArray(writer, "items");
        writer->addStringElement(writer, NULL, "bar");
        writer->addStringElement(writer, NULL, "foo");
        writer->endContainer(writer);
        writer->endContainer(writer);
    });
    id expected = @{@"items": @[@"bar", @"foo"]};
    XCTAssertEqualObjects(object, expected);
}

- (void)testFileElementsInsideArray {
    NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testFileElementsInsideArray.json"];
    [@"{\"foo\":\"bar\"}" writeToFile:temporaryFile atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    id object = JSONObject(^(RSC_KSCrashReportWriter *writer) {
        writer->beginArray(writer, NULL);
        writer->addJSONFileElement(writer, NULL, temporaryFile.fileSystemRepresentation);
        writer->addJSONFileElement(writer, NULL, "/invalid/files/should/be/ignored");
        writer->addJSONFileElement(writer, NULL, temporaryFile.fileSystemRepresentation);
        writer->endContainer(writer);
    });
    id expected = @[@{@"foo": @"bar"}, @{@"foo": @"bar"}];
    XCTAssertEqualObjects(object, expected);
    [[NSFileManager defaultManager] removeItemAtPath:temporaryFile error:NULL];
}

@end
