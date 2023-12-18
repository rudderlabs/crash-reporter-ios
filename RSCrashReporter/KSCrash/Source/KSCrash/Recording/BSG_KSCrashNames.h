//
//  RSC_KSCrashNames.h
//  RSCrashReporter
//
//  Created by Karl Stenerud on 28.09.21.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#ifndef RSC_KSCrashNames_h
#define RSC_KSCrashNames_h

#ifdef __cplusplus
extern "C" {
#endif

#include <mach/machine/vm_types.h>

const char *rsc_kscrashthread_state_name(integer_t state);

#ifdef __cplusplus
}
#endif

#endif /* RSC_KSCrashNames_h */
