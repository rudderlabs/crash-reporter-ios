//
//  KSBacktrace.c
//
//  Created by Karl Stenerud on 2012-01-28.
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

#include "RSC_KSBacktrace_Private.h"

#include "RSC_KSMach.h"
#include "RSCDefines.h"

/**
 * Mask to strip pointer authentication codes from pointers on Arm64e
 * devices. Example usage, assuming the usage is guarded for __arm64__:
 *     uintptr_t ptr_address = ptr & RSC_PACStrippingMaskArm64e;
 */
#if defined(__arm64__)
#define RSC_PACStrippingMaskArm64e 0x0000000fffffffff
#endif

/** Represents an entry in a frame list.
 * This is modeled after the various i386/x64 frame walkers in the xnu source,
 * and seems to work fine in ARM as well. I haven't included the args pointer
 * since it's not needed in this context.
 */
typedef struct RSC_KSFrameEntry {
    /** The previous frame in the list. */
    const struct RSC_KSFrameEntry *const previous;

    /** The instruction address. */
    const uintptr_t return_address;
} RSC_KSFrameEntry;

// Avoiding static functions due to linker issues.

int rsc_ksbt_backtraceLength(
    const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    const uintptr_t instructionAddress =
        rsc_ksmachinstructionAddress(machineContext);

    if (instructionAddress == 0) {
        return 0;
    }

    RSC_KSFrameEntry frame = {0};
    const uintptr_t framePtr = rsc_ksmachframePointer(machineContext);
    if (framePtr == 0 || rsc_ksmachcopyMem((void *)framePtr, &frame,
                                           sizeof(frame)) != KERN_SUCCESS) {
        return 1;
    }
    for (int i = 1; i < RSC_kBacktraceGiveUpPoint; i++) {
        if (frame.previous == 0 ||
            rsc_ksmachcopyMem(frame.previous, &frame, sizeof(frame)) !=
                KERN_SUCCESS) {
            return i;
        }
    }

    return RSC_kBacktraceGiveUpPoint;
}

bool rsc_ksbt_isBacktraceTooLong(
    const RSC_STRUCT_MCONTEXT_L *const machineContext, int maxLength) {
    const uintptr_t instructionAddress =
        rsc_ksmachinstructionAddress(machineContext);

    if (instructionAddress == 0) {
        return 0;
    }

    RSC_KSFrameEntry frame = {0};
    const uintptr_t framePtr = rsc_ksmachframePointer(machineContext);
    if (framePtr == 0 || rsc_ksmachcopyMem((void *)framePtr, &frame,
                                           sizeof(frame)) != KERN_SUCCESS) {
        return 1;
    }
    for (int i = 1; i < maxLength; i++) {
        if (frame.previous == 0 ||
            rsc_ksmachcopyMem(frame.previous, &frame, sizeof(frame)) !=
                KERN_SUCCESS) {
            return false;
        }
    }

    return true;
}

int rsc_ksbt_backtraceThreadState(
    const RSC_STRUCT_MCONTEXT_L *const machineContext,
    uintptr_t *const backtraceBuffer, const int skipEntries,
    const int maxEntries) {
    if (maxEntries == 0) {
        return 0;
    }

    int i = 0;

    if (skipEntries == 0) {
        const uintptr_t instructionAddress =
            rsc_ksmachinstructionAddress(machineContext);
        backtraceBuffer[i] = instructionAddress;
        i++;

        if (i == maxEntries) {
            return i;
        }
    }

    if (skipEntries <= 1) {
        uintptr_t linkRegister = rsc_ksmachlinkRegister(machineContext);

        if (linkRegister) {
            backtraceBuffer[i] = linkRegister;
            i++;

            if (i == maxEntries) {
                return i;
            }
        }
    }

    RSC_KSFrameEntry frame = {0};

    const uintptr_t framePtr = rsc_ksmachframePointer(machineContext);
    if (framePtr == 0 || rsc_ksmachcopyMem((void *)framePtr, &frame,
                                           sizeof(frame)) != KERN_SUCCESS) {
        return i;
    }
    for (int j = 1; j < skipEntries; j++) {
        if (frame.previous == 0 ||
            rsc_ksmachcopyMem(frame.previous, &frame, sizeof(frame)) !=
                KERN_SUCCESS) {
            return i;
        }
    }

    for (; i < maxEntries; i++) {
#if defined(__arm64__)
        // Strip program auth code from address prior to storing address.
        // Intended for Arm64e but is a no-op on other Arm64 archs.
        backtraceBuffer[i] = frame.return_address & RSC_PACStrippingMaskArm64e;
#else
        backtraceBuffer[i] = frame.return_address;
#endif
        if (backtraceBuffer[i] == 0 || frame.previous == 0 ||
            rsc_ksmachcopyMem(frame.previous, &frame, sizeof(frame)) !=
                KERN_SUCCESS) {
            break;
        }
    }
    return i;
}

#if RSC_HAVE_MACH_THREADS
int rsc_ksbt_backtraceThread(const thread_t thread,
                             uintptr_t *const backtraceBuffer,
                             const int maxEntries) {
    RSC_STRUCT_MCONTEXT_L machineContext;

    if (!rsc_ksmachthreadState(thread, &machineContext)) {
        return 0;
    }

    return rsc_ksbt_backtraceThreadState(&machineContext, backtraceBuffer, 0,
                                         maxEntries);
}
#endif

void rsc_ksbt_symbolicate(const uintptr_t *const backtraceBuffer,
                          struct rsc_symbolicate_result *symbolsBuffer, const int numEntries,
                          const int skippedEntries) {
    int i = 0;

    if (!skippedEntries && i < numEntries) {
        rsc_symbolicate(backtraceBuffer[i], &symbolsBuffer[i]);
        i++;
    }

    for (; i < numEntries; i++) {
        rsc_symbolicate(CALL_INSTRUCTION_FROM_RETURN_ADDRESS(backtraceBuffer[i]),
                       &symbolsBuffer[i]);
    }
}
