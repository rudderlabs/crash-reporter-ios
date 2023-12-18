//
//  KSMach_Arm.c
//
//  Created by Karl Stenerud on 2013-09-29.
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

#if defined(__arm64__)

#include "RSC_KSMach.h"
#include "RSCDefines.h"

//#define RSC_KSLogger_LocalLevel TRACE
#include "RSC_KSLogger.h"

static const char *rsc_g_registerNames[] = {
    "x0",  "x1",  "x2",  "x3",  "x4",  "x5",  "x6",  "x7",  "x8",
    "x9",  "x10", "x11", "x12", "x13", "x14", "x15", "x16", "x17",
    "x18", "x19", "x20", "x21", "x22", "x23", "x24", "x25", "x26",
    "x27", "x28", "x29", "fp",  "lr",  "sp",  "pc",  "cpsr"};
static const int rsc_g_registerNamesCount =
    sizeof(rsc_g_registerNames) / sizeof(*rsc_g_registerNames);

static const char *rsc_g_exceptionRegisterNames[] = {"exception", "esr", "far"};
static const int rsc_g_exceptionRegisterNamesCount =
    sizeof(rsc_g_exceptionRegisterNames) /
    sizeof(*rsc_g_exceptionRegisterNames);

uintptr_t
rsc_ksmachframePointer(const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    // Must cast these because while the machine context always stores all registers
    // as 64-bit, some watch devices are actually 64-bit with 32-bit addressing.
    return (uintptr_t)machineContext->__ss.__fp;
}

uintptr_t
rsc_ksmachstackPointer(const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    return (uintptr_t)machineContext->__ss.__sp;
}

uintptr_t rsc_ksmachinstructionAddress(
    const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    return (uintptr_t)machineContext->__ss.__pc;
}

uintptr_t
rsc_ksmachlinkRegister(const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    return (uintptr_t)machineContext->__ss.__lr;
}

#if RSC_HAVE_MACH_THREADS
bool rsc_ksmachthreadState(const thread_t thread,
                           RSC_STRUCT_MCONTEXT_L *const machineContext) {
    return rsc_ksmachfillState(thread, (thread_state_t)&machineContext->__ss,
                               ARM_THREAD_STATE64, ARM_THREAD_STATE64_COUNT);
}

bool rsc_ksmachfloatState(const thread_t thread,
                          RSC_STRUCT_MCONTEXT_L *const machineContext) {
    return rsc_ksmachfillState(thread, (thread_state_t)&machineContext->__ns,
                               ARM_VFP_STATE, ARM_VFP_STATE_COUNT);
}

bool rsc_ksmachexceptionState(const thread_t thread,
                              RSC_STRUCT_MCONTEXT_L *const machineContext) {
    return rsc_ksmachfillState(thread, (thread_state_t)&machineContext->__es,
                               ARM_EXCEPTION_STATE64,
                               ARM_EXCEPTION_STATE64_COUNT);
}
#endif

int rsc_ksmachnumRegisters(void) { return rsc_g_registerNamesCount; }

const char *rsc_ksmachregisterName(const int regNumber) {
    if (regNumber < rsc_ksmachnumRegisters()) {
        return rsc_g_registerNames[regNumber];
    }
    return NULL;
}

uint64_t
rsc_ksmachregisterValue(const RSC_STRUCT_MCONTEXT_L *const machineContext,
                        const int regNumber) {
    if (regNumber <= 29) {
        return machineContext->__ss.__x[regNumber];
    }

    switch (regNumber) {
    case 30:
        return machineContext->__ss.__fp;
    case 31:
        return machineContext->__ss.__lr;
    case 32:
        return machineContext->__ss.__sp;
    case 33:
        return machineContext->__ss.__pc;
    case 34:
        return machineContext->__ss.__cpsr;
    }

    RSC_KSLOG_ERROR("Invalid register number: %d", regNumber);
    return 0;
}

int rsc_ksmachnumExceptionRegisters(void) {
    return rsc_g_exceptionRegisterNamesCount;
}

const char *rsc_ksmachexceptionRegisterName(const int regNumber) {
    if (regNumber < rsc_ksmachnumExceptionRegisters()) {
        return rsc_g_exceptionRegisterNames[regNumber];
    }
    RSC_KSLOG_ERROR("Invalid register number: %d", regNumber);
    return NULL;
}

uint64_t rsc_ksmachexceptionRegisterValue(
    const RSC_STRUCT_MCONTEXT_L *const machineContext, const int regNumber) {
    switch (regNumber) {
    case 0:
        return machineContext->__es.__exception;
    case 1:
        return machineContext->__es.__esr;
    case 2:
        return machineContext->__es.__far;
    }

    RSC_KSLOG_ERROR("Invalid register number: %d", regNumber);
    return 0;
}

uintptr_t
rsc_ksmachfaultAddress(const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    return (uintptr_t)machineContext->__es.__far;
}

int rsc_ksmachstackGrowDirection(void) { return -1; }

#endif
