//
//  RSC_KSMachHeaders.h
//  RSCrashReporter
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 RSCrashReporter. All rights reserved.
//

#ifndef RSC_KSMachHeaders_h
#define RSC_KSMachHeaders_h

#include <stdbool.h>
#include <stdint.h>
#include <stdatomic.h>

/* Maintaining our own list of framework Mach headers means that we avoid potential
 * deadlock situations where we try and suspend lock-holding threads prior to
 * loading mach headers as part of our normal event handling behaviour.
 */

/**
 * An encapsulation of the Mach header data as a linked list - either 64 or 32 bit, along with some additiona
 * information required for detailing a crash report's binary images.
 */
typedef struct rsc_mach_image {

    /// The mach_header or mach_header_64
    ///
    /// This is also the memory address where the __TEXT segment has been loaded by dyld, including slide.
    const struct mach_header *header;

    /// The vmaddr specified for the __TEXT segment
    ///
    /// This is the load address specified at build time, and does not account for slide applied by dyld.
    uint64_t imageVmAddr;

    /// The vmsize of the __TEXT segment
    uint64_t imageSize;

    /// A UUID that uniquely identifies this image, used to identify its associated dSYM
    const uint8_t *uuid;

    /// The pathname of the shared object (Dl_info.dli_fname)
    const char* name;

    /// The virtual memory address slide of the image
    intptr_t slide;

    /// True if the image has been unloaded and should be ignored
    bool unloaded;
    
    /// True if the image is referenced by the current crash report.
    bool inCrashReport;

    /// The next image in the linked list
    _Atomic(struct rsc_mach_image *) next;
} RSC_Mach_Header_Info;

// MARK: - Operations

/**
 * Initialize the headers management system.
 * This MUST be called before calling anything else.
 */
void rsc_mach_headers_initialize(void);

/**
 * Returns the head of the link list of headers
 */
RSC_Mach_Header_Info *rsc_mach_headers_get_images(void);

/**
 * Returns the process's main image
 */
RSC_Mach_Header_Info *rsc_mach_headers_get_main_image(void);

/**
 * Returns the image that contains KSCrash.
 */
RSC_Mach_Header_Info *rsc_mach_headers_get_self_image(void);

/**
 * Find the loaded binary image that contains the specified instruction address.
*/
RSC_Mach_Header_Info *rsc_mach_headers_image_at_address(const uintptr_t address);


/** Find a loaded binary image with the specified name.
 *
 * @param imageName The image name to look for.
 *
 * @param exactMatch If true, look for an exact match instead of a partial one.
 *
 * @return the matched image, or NULL if not found.
 */
RSC_Mach_Header_Info *rsc_mach_headers_image_named(const char *const imageName, bool exactMatch);

/** Get the address of the first command following a header (which will be of
 * type struct load_command).
 *
 * @param header The header to get commands for.
 *
 * @return The address of the first command, or NULL if none was found (which
 *         should not happen unless the header or image is corrupt).
 */
uintptr_t rsc_mach_headers_first_cmd_after_header(const struct mach_header *header);

/** Get the __crash_info message of the specified image.
 *
 * @param header The header to get commands for.
 * @return The __crash_info message, or NULL if no readable message could be found.
 */
const char *rsc_mach_headers_get_crash_info_message(const RSC_Mach_Header_Info *header);

/**
 * Resets mach header data (for unit tests).
 */
void rsc_test_support_mach_headers_reset(void);

/**
 * Add a binary image (for unit tests).
 */
void rsc_test_support_mach_headers_add_image(const struct mach_header *mh, intptr_t slide);

/**
 * Remove a binary image (for unit tests).
 */
void rsc_test_support_mach_headers_remove_image(const struct mach_header *mh, intptr_t slide);

#endif /* RSC_KSMachHeaders_h */
