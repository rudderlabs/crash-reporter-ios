//
//  RSC_Symbolicate.h
//  RSCrashReporter
//
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#ifndef RSC_Symbolicate_h
#define RSC_Symbolicate_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

struct rsc_symbolicate_result {
    struct rsc_mach_image *image;
    uintptr_t function_address;
    const char *function_name;
};

void rsc_symbolicate(const uintptr_t address, struct rsc_symbolicate_result *result);

#ifdef __cplusplus
}
#endif

#endif // RSC_Symbolicate_h
