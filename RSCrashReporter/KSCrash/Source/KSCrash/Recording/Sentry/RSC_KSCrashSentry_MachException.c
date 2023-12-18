//
//  RSC_KSCrashSentry_MachException.c
//
//  Created by Karl Stenerud on 2012-02-04.
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

#include "RSCDefines.h"

#if RSC_HAVE_MACH_EXCEPTIONS

#include "RSC_KSCrashSentry_MachException.h"

//#define RSC_KSLogger_LocalLevel TRACE
#include "RSC_KSLogger.h"
#include "RSC_KSCrashC.h"

#include "RSC_KSMach.h"
#include "RSC_KSCrashSentry_Private.h"
#include <pthread.h>
#include <mach/mach.h>

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define kThreadPrimary "KSCrash Exception Handler (Primary)"
#define kThreadSecondary "KSCrash Exception Handler (Secondary)"

#ifdef __LP64__
    #define MACH_ERROR_CODE_MASK 0xFFFFFFFFFFFFFFFF
#else
    #define MACH_ERROR_CODE_MASK 0xFFFFFFFF
#endif

// ============================================================================
#pragma mark - Types -
// ============================================================================

/** A mach exception message (according to ux_exception.c, xnu-1699.22.81).
 */
#pragma pack(4)
typedef struct {
    /** Mach header. */
    mach_msg_header_t header;

    // Start of the kernel processed data.

    /** Basic message body data. */
    mach_msg_body_t body;

    /** The thread that raised the exception. */
    mach_msg_port_descriptor_t thread;

    /** The task that raised the exception. */
    mach_msg_port_descriptor_t task;

    // End of the kernel processed data.

    /** Network Data Representation. */
    NDR_record_t NDR;

    /** The exception that was raised. */
    exception_type_t exception;

    /** The number of codes. */
    mach_msg_type_number_t codeCount;

    /** Exception code and subcode. */
    // ux_exception.c defines this as mach_exception_data_t for some reason.
    // But it's not actually a pointer; it's an embedded array.
    // On 32-bit systems, only the lower 32 bits of the code and subcode
    // are valid.
    mach_exception_data_type_t code[0];

    /** Padding to avoid RCV_TOO_LARGE. */
    char padding[512];
} MachExceptionMessage;
#pragma pack()

/** A mach reply message (according to ux_exception.c, xnu-1699.22.81).
 */
#pragma pack(4)
typedef struct {
    /** Mach header. */
    mach_msg_header_t header;

    /** Network Data Representation. */
    NDR_record_t NDR;

    /** Return code. */
    kern_return_t returnCode;
} MachReplyMessage;
#pragma pack()

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Flag noting if we've installed our custom handlers or not.
 * It's not fully thread safe, but it's safer than locking and slightly better
 * than nothing.
 */
static volatile sig_atomic_t rsc_g_installed = 0;

/** Holds exception port info regarding the previously installed exception
 * handlers.
 */
static struct {
    exception_mask_t masks[EXC_TYPES_COUNT];
    exception_handler_t ports[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t count;
} rsc_g_previousExceptionPorts;

/** Our exception port. */
static mach_port_t rsc_g_exceptionPort = MACH_PORT_NULL;

/** Primary exception handler thread. */
static pthread_t rsc_g_primaryPThread;
static thread_t rsc_g_primaryMachThread;

/** Secondary exception handler thread in case crash handler crashes. */
static pthread_t rsc_g_secondaryPThread;
static thread_t rsc_g_secondaryMachThread;

/** Context to fill with crash information. */
static RSC_KSCrash_SentryContext *rsc_g_context;

// ============================================================================
#pragma mark - Utility -
// ============================================================================

// Avoiding static methods due to linker issue.

/** Get all parts of the machine state required for a dump.
 * This includes basic thread state, and exception registers.
 *
 * @param thread The thread to get state for.
 *
 * @param machineContext The machine context to fill out.
 */
bool rsc_ksmachexc_i_fetchMachineState(
    const thread_t thread, RSC_STRUCT_MCONTEXT_L *const machineContext) {
    if (!rsc_ksmachthreadState(thread, machineContext)) {
        return false;
    }

    if (!rsc_ksmachexceptionState(thread, machineContext)) {
        return false;
    }

    return true;
}

/** Restore the original mach exception ports.
 */
void rsc_ksmachexc_i_restoreExceptionPorts(void) {
    RSC_KSLOG_DEBUG("Restoring original exception ports.");
    if (rsc_g_previousExceptionPorts.count == 0) {
        RSC_KSLOG_DEBUG("Original exception ports were already restored.");
        return;
    }

    const task_t thisTask = mach_task_self();
    kern_return_t kr;

    // Reinstall old exception ports.
    for (mach_msg_type_number_t i = 0; i < rsc_g_previousExceptionPorts.count;
         i++) {
        RSC_KSLOG_TRACE("Restoring port index %d", i);
        kr = task_set_exception_ports(thisTask,
                                      rsc_g_previousExceptionPorts.masks[i],
                                      rsc_g_previousExceptionPorts.ports[i],
                                      rsc_g_previousExceptionPorts.behaviors[i],
                                      rsc_g_previousExceptionPorts.flavors[i]);
        if (kr != KERN_SUCCESS) {
            RSC_KSLOG_ERROR("task_set_exception_ports: %s",
                            mach_error_string(kr));
        }
    }
    RSC_KSLOG_DEBUG("Exception ports restored.");
    rsc_g_previousExceptionPorts.count = 0;
}

// ============================================================================
#pragma mark - Handler -
// ============================================================================

/** Our exception handler thread routine.
 * Wait for an exception message, uninstall our exception port, record the
 * exception information, and write a report.
 */
void *ksmachexc_i_handleExceptions(void *const userData) {
    MachExceptionMessage exceptionMessage = {{0}};
    MachReplyMessage replyMessage = {{0}};

    const char *threadName = (const char *)userData;
    pthread_setname_np(threadName);
    if (strcmp(threadName, kThreadSecondary) == 0) {
        RSC_KSLOG_DEBUG("This is the secondary thread. Suspending.");
        thread_suspend(rsc_ksmachthread_self());
    }

    while (rsc_g_installed) {
        RSC_KSLOG_DEBUG("Waiting for mach exception");

        // Wait for a message.
        mach_msg_return_t result = mach_msg(
            &exceptionMessage.header, MACH_RCV_MSG, 0, sizeof(exceptionMessage),
            rsc_g_exceptionPort, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        if (result == MACH_MSG_SUCCESS) {
            break;
        }

        // Loop and try again on failure.
        RSC_KSLOG_ERROR("mach_msg: %d", result);
    }

    RSC_KSLOG_DEBUG("Trapped mach exception code 0x%llx, subcode 0x%llx",
                    exceptionMessage.code[0], exceptionMessage.code[1]);
    if (rsc_g_installed &&
        rsc_kscrashsentry_beginHandlingCrash(exceptionMessage.thread.name)) {

        RSC_KSLOG_DEBUG("Suspending all threads");
        rsc_kscrashsentry_suspendThreads();

        // Switch to the secondary thread if necessary, or uninstall the handler
        // to avoid a death loop.
        if (rsc_ksmachthread_self() == rsc_g_primaryMachThread) {
            RSC_KSLOG_DEBUG("This is the primary exception thread. Activating "
                            "secondary thread.");
            if (thread_resume(rsc_g_secondaryMachThread) != KERN_SUCCESS) {
                RSC_KSLOG_DEBUG("Could not activate secondary thread. "
                                "Restoring original exception ports.");
                rsc_ksmachexc_i_restoreExceptionPorts();
            }
        } else {
            RSC_KSLOG_DEBUG("This is the secondary exception thread. Restoring "
                            "original exception ports.");
            rsc_ksmachexc_i_restoreExceptionPorts();
        }

        // Fill out crash information
        RSC_KSLOG_DEBUG("Fetching machine state.");
        RSC_STRUCT_MCONTEXT_L machineContext;
        if (rsc_ksmachexc_i_fetchMachineState(exceptionMessage.thread.name,
                                              &machineContext)) {
            if (exceptionMessage.exception == EXC_BAD_ACCESS) {
                rsc_g_context->faultAddress =
                    rsc_ksmachfaultAddress(&machineContext);
            } else {
                rsc_g_context->faultAddress =
                    rsc_ksmachinstructionAddress(&machineContext);
            }
        }

        RSC_KSLOG_DEBUG("Filling out context.");
        rsc_g_context->crashType = RSC_KSCrashTypeMachException;
        rsc_g_context->registersAreValid = true;
        rsc_g_context->mach.type = exceptionMessage.exception;
        rsc_g_context->mach.code = exceptionMessage.code[0] & (int64_t)MACH_ERROR_CODE_MASK;
        rsc_g_context->mach.subcode = exceptionMessage.code[1] & (int64_t)MACH_ERROR_CODE_MASK;

        RSC_KSLOG_DEBUG("Calling main crash handler.");
        rsc_g_context->onCrash(crashContext());

        RSC_KSLOG_DEBUG(
            "Crash handling complete. Restoring original handlers.");
        rsc_kscrashsentry_uninstall(RSC_KSCrashTypeAsyncSafe);
        rsc_kscrashsentry_resumeThreads();

        // Must run before endHandlingCrash unblocks secondary crashed threads.
        RSC_KSCrash_Context *context = crashContext();
        if (context->crash.attemptDelivery) {
            RSC_KSLOG_DEBUG("Attempting delivery.");
            context->crash.attemptDelivery();
        }

        rsc_kscrashsentry_endHandlingCrash();
    }

    RSC_KSLOG_DEBUG("Replying to mach exception message.");
    // Send a reply saying "I didn't handle this exception".
    replyMessage.header = exceptionMessage.header;
    replyMessage.NDR = exceptionMessage.NDR;
    replyMessage.returnCode = KERN_FAILURE;

    mach_msg(&replyMessage.header, MACH_SEND_MSG, sizeof(replyMessage), 0,
             MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

    return NULL;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

bool rsc_kscrashsentry_installMachHandler(
    RSC_KSCrash_SentryContext *const context) {
    RSC_KSLOG_DEBUG("Installing mach exception handler.");

    bool attributes_created = false;
    pthread_attr_t attr;

    kern_return_t kr;
    int error;

    const task_t thisTask = mach_task_self();
    exception_mask_t mask = EXC_MASK_BAD_ACCESS | EXC_MASK_BAD_INSTRUCTION |
                            EXC_MASK_ARITHMETIC | EXC_MASK_SOFTWARE |
                            EXC_MASK_BREAKPOINT;

    if (rsc_g_installed) {
        return true;
    }
    rsc_g_installed = 1;

    if (rsc_ksmachisBeingTraced()) {
        // Different debuggers hook into different exception types.
        // For example, GDB uses EXC_BAD_ACCESS for single stepping,
        // and LLDB uses EXC_SOFTWARE to stop a debug session.
        // Because of this, it's safer to not hook into the mach exception
        // system at all while being debugged.
        RSC_KSLOG_WARN("Process is being debugged. Not installing handler.");
        goto failed;
    }

    rsc_g_context = context;

    RSC_KSLOG_DEBUG("Backing up original exception ports.");
    kr = task_get_exception_ports(
        thisTask, mask, rsc_g_previousExceptionPorts.masks,
        &rsc_g_previousExceptionPorts.count, rsc_g_previousExceptionPorts.ports,
        rsc_g_previousExceptionPorts.behaviors,
        rsc_g_previousExceptionPorts.flavors);
    if (kr != KERN_SUCCESS) {
        RSC_KSLOG_ERROR("task_get_exception_ports: %s", mach_error_string(kr));
        goto failed;
    }

    if (rsc_g_exceptionPort == MACH_PORT_NULL) {
        RSC_KSLOG_DEBUG("Allocating new port with receive rights.");
        kr = mach_port_allocate(thisTask, MACH_PORT_RIGHT_RECEIVE,
                                &rsc_g_exceptionPort);
        if (kr != KERN_SUCCESS) {
            RSC_KSLOG_ERROR("mach_port_allocate: %s", mach_error_string(kr));
            goto failed;
        }

        RSC_KSLOG_DEBUG("Adding send rights to port.");
        kr = mach_port_insert_right(thisTask, rsc_g_exceptionPort,
                                    rsc_g_exceptionPort,
                                    MACH_MSG_TYPE_MAKE_SEND);
        if (kr != KERN_SUCCESS) {
            RSC_KSLOG_ERROR("mach_port_insert_right: %s",
                            mach_error_string(kr));
            goto failed;
        }
    }

    RSC_KSLOG_DEBUG("Installing port as exception handler.");
    kr = task_set_exception_ports(thisTask, mask, rsc_g_exceptionPort,
                                  (int)(EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES),
                                  THREAD_STATE_NONE);
    if (kr != KERN_SUCCESS) {
        RSC_KSLOG_ERROR("task_set_exception_ports: %s", mach_error_string(kr));
        goto failed;
    }

    RSC_KSLOG_DEBUG("Creating secondary exception thread (suspended).");
    pthread_attr_init(&attr);
    attributes_created = true;
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    error = pthread_create(&rsc_g_secondaryPThread, &attr,
                           &ksmachexc_i_handleExceptions, kThreadSecondary);
    if (error != 0) {
        RSC_KSLOG_ERROR("pthread_create_suspended_np: %s", strerror(error));
        goto failed;
    }
    rsc_g_secondaryMachThread = pthread_mach_thread_np(rsc_g_secondaryPThread);
    context->reservedThreads[RSC_KSCrashReservedThreadTypeMachSecondary] =
        rsc_g_secondaryMachThread;

    RSC_KSLOG_DEBUG("Creating primary exception thread.");
    error = pthread_create(&rsc_g_primaryPThread, &attr,
                           &ksmachexc_i_handleExceptions, kThreadPrimary);
    if (error != 0) {
        RSC_KSLOG_ERROR("pthread_create: %s", strerror(error));
        goto failed;
    }
    pthread_attr_destroy(&attr);
    rsc_g_primaryMachThread = pthread_mach_thread_np(rsc_g_primaryPThread);
    context->reservedThreads[RSC_KSCrashReservedThreadTypeMachPrimary] =
        rsc_g_primaryMachThread;

    RSC_KSLOG_DEBUG("Mach exception handler installed.");
    return true;

failed:
    RSC_KSLOG_DEBUG("Failed to install mach exception handler.");
    if (attributes_created) {
        pthread_attr_destroy(&attr);
    }
    rsc_kscrashsentry_uninstallMachHandler();
    return false;
}

void rsc_kscrashsentry_uninstallMachHandler(void) {
    RSC_KSLOG_DEBUG("Uninstalling mach exception handler.");

    if (!rsc_g_installed) {
        return;
    }

    // NOTE: Do not deallocate the exception port. If a secondary crash occurs
    // it will hang the process.

    rsc_ksmachexc_i_restoreExceptionPorts();

    rsc_g_installed = 0;

    if (rsc_g_context->handlingCrash) {
        // Terminating a thread that is currently handling an exception message
        // can cause a deadlock, so let's not do that!
        RSC_KSLOG_DEBUG("Not cancelling exception threads.");
        return;
    }

    thread_t thread_self = rsc_ksmachthread_self();

    if (rsc_g_primaryPThread != 0 && rsc_g_primaryMachThread != thread_self) {
        RSC_KSLOG_DEBUG("Cancelling primary exception thread.");
        if (rsc_g_context->handlingCrash) {
            thread_terminate(rsc_g_primaryMachThread);
        } else {
            pthread_cancel(rsc_g_primaryPThread);
        }
        rsc_g_primaryMachThread = 0;
        rsc_g_primaryPThread = 0;
    }
    if (rsc_g_secondaryPThread != 0 && rsc_g_secondaryMachThread != thread_self) {
        RSC_KSLOG_DEBUG("Cancelling secondary exception thread.");
        if (rsc_g_context->handlingCrash) {
            thread_terminate(rsc_g_secondaryMachThread);
        } else {
            pthread_cancel(rsc_g_secondaryPThread);
        }
        rsc_g_secondaryMachThread = 0;
        rsc_g_secondaryPThread = 0;
    }
}

#endif
