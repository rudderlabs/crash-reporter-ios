//
//  RSC_KSMachHeadersTests.m
//  Tests
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#import "RSC_KSMachHeaders.h"
#import <RSCrashReporter/RSCrashReporter.h>
#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

const struct mach_header header1 = {
    .magic = MH_MAGIC,
    .cputype = 0,
    .cpusubtype = 0,
    .filetype = 0,
    .ncmds = 1,
    .sizeofcmds = 0,
    .flags = 0
};
const struct segment_command command1 = {
    .cmd = LC_SEGMENT,
    .cmdsize = 0,
    .segname = SEG_TEXT,
    .vmaddr = 111,
    .vmsize = 10,
};

const struct mach_header header2 = {
    .magic = MH_MAGIC,
    .cputype = 0,
    .cpusubtype = 0,
    .filetype = 0,
    .ncmds = 1,
    .sizeofcmds = 0,
    .flags = 0
};
const struct segment_command command2 = {
    .cmd = LC_SEGMENT,
    .cmdsize = 0,
    .segname = SEG_TEXT,
    .vmaddr = 222,
    .vmsize = 10,
};

@interface RSC_KSMachHeadersTests : XCTestCase
@end

@implementation RSC_KSMachHeadersTests

- (void)setUp {
    rsc_mach_headers_initialize();
}

static RSC_Mach_Header_Info *get_tail(RSC_Mach_Header_Info *head) {
    RSC_Mach_Header_Info *current = head;
    for (; current->next != NULL; current = current->next) {
    }
    return current;
}

- (void)testAddRemove {
    rsc_test_support_mach_headers_reset();

    rsc_test_support_mach_headers_add_image(&header1, 0);
    
    RSC_Mach_Header_Info *listTail = get_tail(rsc_mach_headers_get_images());
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == FALSE);
    
    rsc_test_support_mach_headers_add_image(&header2, 0);
    
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == FALSE);
    XCTAssertEqual(listTail->next->imageVmAddr, command2.vmaddr);
    XCTAssert(listTail->next->unloaded == FALSE);
    
    rsc_test_support_mach_headers_remove_image(&header1, 0);
    
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == TRUE);
    XCTAssertEqual(listTail->next->imageVmAddr, command2.vmaddr);
    XCTAssert(listTail->next->unloaded == FALSE);
    
    rsc_test_support_mach_headers_remove_image(&header2, 0);
    
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == TRUE);
    XCTAssertEqual(listTail->next->imageVmAddr, command2.vmaddr);
    XCTAssert(listTail->next->unloaded == TRUE);
}

- (void)testFindImageAtAddress {
    rsc_test_support_mach_headers_reset();

    rsc_test_support_mach_headers_add_image(&header1, 0);
    rsc_test_support_mach_headers_add_image(&header2, 0);
    
    RSC_Mach_Header_Info *item;
    item = rsc_mach_headers_image_at_address((uintptr_t)&header1);
    XCTAssertEqual(item->imageVmAddr, command1.vmaddr);
    
    item = rsc_mach_headers_image_at_address((uintptr_t)&header2);
    XCTAssertEqual(item->imageVmAddr, command2.vmaddr);
}

- (void) testGetImageNameNULL
{
    RSC_Mach_Header_Info *img = rsc_mach_headers_image_named(NULL, false);
    XCTAssertTrue(img == NULL);
}

- (void)testGetSelfImage {
    XCTAssertEqualObjects(@(rsc_mach_headers_get_self_image()->name),
                          @(class_getImageName([RSCrashReporter class])));
}

- (void)testMainImage {
    XCTAssertEqualObjects(@(rsc_mach_headers_get_main_image()->name),
                          NSBundle.mainBundle.executablePath);
}

- (void)testImageAtAddress {
    for (NSNumber *number in NSThread.callStackReturnAddresses) {
        uintptr_t address = number.unsignedIntegerValue;
        RSC_Mach_Header_Info *image = rsc_mach_headers_image_at_address(address);
        struct dl_info dlinfo = {0};
        if (dladdr((const void*)address, &dlinfo) != 0) {
            // If dladdr was able to locate the image, so should rsc_mach_headers_image_at_address
            XCTAssertEqual(image->header, dlinfo.dli_fbase);
            XCTAssertEqual(image->imageVmAddr + image->slide, (uint64_t)dlinfo.dli_fbase);
            XCTAssertEqual(image->name, dlinfo.dli_fname);
            XCTAssertFalse(image->unloaded);
        }
    }
    
    XCTAssertEqual(rsc_mach_headers_image_at_address(0x0000000000000000), NULL);
    XCTAssertEqual(rsc_mach_headers_image_at_address(0x0000000000001000), NULL);
    XCTAssertEqual(rsc_mach_headers_image_at_address(0x7FFFFFFFFFFFFFFF), NULL);
}

@end
