//
//  RSC_KSCrashReport.m
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

#include "RSC_KSCrashReport.h"

#include "RSC_KSBacktrace_Private.h"
#include "RSC_KSCrashReportFields.h"
#include "RSC_KSCrashReportVersion.h"
#include "RSC_KSFile.h"
#include "RSC_KSFileUtils.h"
#include "RSC_KSJSONCodec.h"
#include "RSC_KSMach.h"
#include "RSC_KSSignalInfo.h"
#include "RSC_KSString.h"
#include "RSC_KSMachHeaders.h"
#include "RSC_KSCrashNames.h"
#include "RSC_KSCrashStringConversion.h"

//#define RSC_kSLogger_LocalLevel TRACE
#include "RSC_KSLogger.h"
#include "RSC_KSCrashContext.h"
#include "RSC_KSCrashSentry.h"
#include "RSC_Symbolicate.h"
#include "RSCDefines.h"
#include "RSCRunContext.h"

#include <mach-o/loader.h>
#include <sys/time.h>

#ifdef __arm64__
#include <sys/_types/_ucontext64.h>
#define RSC_UC_MCONTEXT uc_mcontext64
typedef ucontext64_t SignalUserContext;
#else
#define RSC_UC_MCONTEXT uc_mcontext
typedef ucontext_t SignalUserContext;
#endif

// Note: Avoiding static functions due to linker issues.

// ============================================================================
#pragma mark - Constants -
// ============================================================================

/** Maximum depth allowed for a backtrace. */
#define RSC_kMaxBacktraceDepth 150

/** Length at which we consider a backtrace to represent a stack overflow.
 * If it reaches this point, we start cutting off from the top of the stack
 * rather than the bottom.
 */
#define RSC_kStackOverflowThreshold 200

typedef struct {
    char *data;
    size_t allocated_size;
} RSC_ThreadDataBuffer;

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

#define rsc_getJsonContext(REPORT_WRITER)                                      \
    ((RSC_KSJSONEncodeContext *)((REPORT_WRITER)->context))

/** Used for writing hex string values. */
static const char rsc_g_hexNybbles[] = {'0', '1', '2', '3', '4', '5', '6', '7',
                                        '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

// ============================================================================
#pragma mark - Runtime Config -
// ============================================================================

#pragma mark Callbacks

void rsc_kscrw_i_addBooleanElement(const RSC_KSCrashReportWriter *const writer,
                                   const char *const key, const bool value) {
    rsc_ksjsonaddBooleanElement(rsc_getJsonContext(writer), key, value);
}

void rsc_kscrw_i_addFloatingPointElement(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const double value) {
    rsc_ksjsonaddFloatingPointElement(rsc_getJsonContext(writer), key, value);
}

void rsc_kscrw_i_addIntegerElement(const RSC_KSCrashReportWriter *const writer,
                                   const char *const key,
                                   const long long value) {
    rsc_ksjsonaddIntegerElement(rsc_getJsonContext(writer), key, value);
}

void rsc_kscrw_i_addUIntegerElement(const RSC_KSCrashReportWriter *const writer,
                                    const char *const key,
                                    const unsigned long long value) {
    rsc_ksjsonaddUIntegerElement(rsc_getJsonContext(writer), key, value);
}

void rsc_kscrw_i_addStringElement(const RSC_KSCrashReportWriter *const writer,
                                  const char *const key,
                                  const char *const value) {
    rsc_ksjsonaddStringElement(rsc_getJsonContext(writer), key, value,
                               RSC_KSJSON_SIZE_AUTOMATIC);
}

void rsc_kscrw_i_addTextFileElement(const RSC_KSCrashReportWriter *const writer,
                                    const char *const key,
                                    const char *const filePath) {
    const int fd = open(filePath, O_RDONLY);
    if (fd < 0) {
        RSC_KSLOG_ERROR("Could not open file %s: %s", filePath,
                        strerror(errno));
        return;
    }

    if (rsc_ksjsonbeginStringElement(rsc_getJsonContext(writer), key) !=
        RSC_KSJSON_OK) {
        RSC_KSLOG_ERROR("Could not start string element");
        goto done;
    }

    char buffer[512];
    ssize_t bytesRead;
    for (bytesRead = read(fd, buffer, sizeof(buffer)); bytesRead > 0;
         bytesRead = read(fd, buffer, sizeof(buffer))) {
        if (rsc_ksjsonappendStringElement(rsc_getJsonContext(writer), buffer,
                                          (size_t)bytesRead) != RSC_KSJSON_OK) {
            RSC_KSLOG_ERROR("Could not append string element");
            goto done;
        }
    }

done:
    rsc_ksjsonendStringElement(rsc_getJsonContext(writer));
    close(fd);
}

void rsc_kscrw_i_addDataElement(const RSC_KSCrashReportWriter *const writer,
                                const char *const key, const char *const value,
                                const size_t length) {
    rsc_ksjsonaddDataElement(rsc_getJsonContext(writer), key, value, length);
}

void rsc_kscrw_i_beginDataElement(const RSC_KSCrashReportWriter *const writer,
                                  const char *const key) {
    rsc_ksjsonbeginDataElement(rsc_getJsonContext(writer), key);
}

void rsc_kscrw_i_appendDataElement(const RSC_KSCrashReportWriter *const writer,
                                   const char *const value,
                                   const size_t length) {
    rsc_ksjsonappendDataElement(rsc_getJsonContext(writer), value, length);
}

void rsc_kscrw_i_endDataElement(const RSC_KSCrashReportWriter *const writer) {
    rsc_ksjsonendDataElement(rsc_getJsonContext(writer));
}

void rsc_kscrw_i_addUUIDElement(const RSC_KSCrashReportWriter *const writer,
                                const char *const key,
                                const unsigned char *const value) {
    if (value == NULL) {
        rsc_ksjsonaddNullElement(rsc_getJsonContext(writer), key);
    } else {
        char uuidBuffer[37];
        const unsigned char *src = value;
        char *dst = uuidBuffer;
        for (int i = 0; i < 4; i++) {
            *dst++ = rsc_g_hexNybbles[(*src >> 4) & 15];
            *dst++ = rsc_g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = rsc_g_hexNybbles[(*src >> 4) & 15];
            *dst++ = rsc_g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = rsc_g_hexNybbles[(*src >> 4) & 15];
            *dst++ = rsc_g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = rsc_g_hexNybbles[(*src >> 4) & 15];
            *dst++ = rsc_g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 6; i++) {
            *dst++ = rsc_g_hexNybbles[(*src >> 4) & 15];
            *dst++ = rsc_g_hexNybbles[(*src++) & 15];
        }

        rsc_ksjsonaddStringElement(rsc_getJsonContext(writer), key, uuidBuffer,
                                   (size_t)(dst - uuidBuffer));
    }
}

void rsc_kscrw_i_addJSONElement(const RSC_KSCrashReportWriter *const writer,
                                const char *const key,
                                const char *const jsonElement) {
    int jsonResult = rsc_ksjsonaddJSONElement(rsc_getJsonContext(writer), key,
                                              jsonElement, strlen(jsonElement));
    if (jsonResult != RSC_KSJSON_OK) {
        char errorBuff[100] = "Invalid JSON data: ";
        const size_t baseLength = strlen(errorBuff);
        strncpy(errorBuff+baseLength, rsc_ksjsonstringForError(jsonResult), sizeof(errorBuff) - baseLength);
        errorBuff[sizeof(errorBuff)-1] = 0;
        rsc_ksjsonbeginObject(rsc_getJsonContext(writer), key);
        rsc_ksjsonaddStringElement(rsc_getJsonContext(writer),
                                   RSC_KSCrashField_Error, errorBuff,
                                   RSC_KSJSON_SIZE_AUTOMATIC);
        rsc_ksjsonaddStringElement(rsc_getJsonContext(writer),
                                   RSC_KSCrashField_JSONData, jsonElement,
                                   RSC_KSJSON_SIZE_AUTOMATIC);
        rsc_ksjsonendContainer(rsc_getJsonContext(writer));
    }
}

void rsc_kscrw_i_addJSONElementFromFile(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const char *const filePath) {
    const int fd = open(filePath, O_RDONLY);
    if (fd < 0) {
        RSC_KSLOG_ERROR("Could not open file %s: %s", filePath,
                        strerror(errno));
        return;
    }

    if (rsc_ksjsonbeginElement(rsc_getJsonContext(writer), key) !=
        RSC_KSJSON_OK) {
        RSC_KSLOG_ERROR("Could not start JSON element");
        goto done;
    }

    char buffer[512];
    ssize_t bytesRead;
    while ((bytesRead = read(fd, buffer, sizeof(buffer))) > 0) {
        if (rsc_ksjsonaddRawJSONData(rsc_getJsonContext(writer), buffer,
                                     (size_t)bytesRead) != RSC_KSJSON_OK) {
            RSC_KSLOG_ERROR("Could not append JSON data");
            goto done;
        }
    }

done:
    close(fd);
}

void rsc_kscrw_i_beginObject(const RSC_KSCrashReportWriter *const writer,
                             const char *const key) {
    rsc_ksjsonbeginObject(rsc_getJsonContext(writer), key);
}

void rsc_kscrw_i_beginArray(const RSC_KSCrashReportWriter *const writer,
                            const char *const key) {
    rsc_ksjsonbeginArray(rsc_getJsonContext(writer), key);
}

void rsc_kscrw_i_endContainer(const RSC_KSCrashReportWriter *const writer) {
    rsc_ksjsonendContainer(rsc_getJsonContext(writer));
}

int rsc_kscrw_i_addJSONData(const char *const data, const size_t length,
                            void *const userData) {
    bool success = RSC_KSFileWrite(userData, data, length);
    return success ? RSC_KSJSON_OK : RSC_KSJSON_ERROR_CANNOT_ADD_DATA;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

#if RSC_HAVE_MACH_THREADS
/** Get all parts of the machine state required for a dump.
 * This includes basic thread state, and exception registers.
 *
 * @param thread The thread to get state for.
 *
 * @param machineContextBuffer The machine context to fill out.
 */
bool rsc_kscrw_i_fetchMachineState(
    const thread_t thread, RSC_STRUCT_MCONTEXT_L *const machineContextBuffer) {
    if (!rsc_ksmachthreadState(thread, machineContextBuffer)) {
        return false;
    }

    if (!rsc_ksmachexceptionState(thread, machineContextBuffer)) {
        return false;
    }

    return true;
}
#endif

/** Get the machine context for the specified thread.
 *
 * This function will choose how to fetch the machine context based on what kind
 * of thread it is (current, crashed, other), and what kind of crash occured.
 * It may store the context in machineContextBuffer unless it can be fetched
 * directly from memory. Do not count on machineContextBuffer containing
 * anything. Always use the return value.
 *
 * @param crash The crash handler context.
 *
 * @param thread The thread to get a machine context for.
 *
 * @param machineContextBuffer A place to store the context, if needed.
 *
 * @return A pointer to the crash context, or NULL if not found.
 */
RSC_STRUCT_MCONTEXT_L *rsc_kscrw_i_getMachineContext(
    const RSC_KSCrash_SentryContext *const crash, const thread_t thread,
    RSC_STRUCT_MCONTEXT_L *const machineContextBuffer) {
    if (thread == crash->offendingThread) {
        if (crash->crashType == RSC_KSCrashTypeSignal) {
            return ((const SignalUserContext *)crash->signal.userContext)
                ->RSC_UC_MCONTEXT;
        }
    }

    if (thread == rsc_ksmachthread_self()) {
        return NULL;
    }

#if RSC_HAVE_MACH_THREADS
    if (rsc_kscrw_i_fetchMachineState(thread, machineContextBuffer)) {
        return machineContextBuffer;
    }
    RSC_KSLOG_ERROR("Failed to fetch machine state for thread %d", thread);
#else
    (void)machineContextBuffer; // Suppress unused parameter warning
#endif

    return NULL;
}

/** Get the backtrace for the specified thread.
 *
 * This function will choose how to fetch the backtrace based on machine context
 * availability andwhat kind of crash occurred. It may store the backtrace in
 * backtraceBuffer unless it can be fetched directly from memory. Do not count
 * on backtraceBuffer containing anything. Always use the return value.
 *
 * @param crash The crash handler context.
 *
 * @param thread The thread to get a machine context for.
 *
 * @param machineContext The machine context (can be NULL).
 *
 * @param backtraceBuffer A place to store the backtrace, if needed.
 *
 * @param backtraceLength In: The length of backtraceBuffer.
 *                        Out: The length of the backtrace.
 *
 * @param skippedEntries Out: The number of entries that were skipped due to
 *                             stack overflow.
 *
 * @return The backtrace, or NULL if not found.
 */
uintptr_t *rsc_kscrw_i_getBacktrace(
    const RSC_KSCrash_SentryContext *const crash, const thread_t thread,
    const RSC_STRUCT_MCONTEXT_L *const machineContext,
    uintptr_t *const backtraceBuffer, int *const backtraceLength,
    int *const skippedEntries) {
    if (thread == crash->offendingThread) {
        if (crash->stackTrace != NULL && crash->stackTraceLength > 0 &&
            (crash->crashType &
             (RSC_KSCrashTypeCPPException | RSC_KSCrashTypeNSException))) {
            *backtraceLength = crash->stackTraceLength;
            return crash->stackTrace;
        }
    }

    int actualSkippedEntries = 0;

    if (machineContext != NULL) {
        int actualLength = rsc_ksbt_backtraceLength(machineContext);
        if (actualLength >= RSC_kStackOverflowThreshold) {
            actualSkippedEntries = actualLength - *backtraceLength;
        }

        *backtraceLength =
            rsc_ksbt_backtraceThreadState(machineContext, backtraceBuffer,
                                          actualSkippedEntries, *backtraceLength);
        if (skippedEntries != NULL) {
            *skippedEntries = actualSkippedEntries;
        }
        return backtraceBuffer;
     }
    
    return NULL;
}

/** Check if the stack for the specified thread has overflowed.
 *
 * @param crash The crash handler context.
 *
 * @param thread The thread to check.
 *
 * @return true if the thread's stack has overflowed.
 */
bool rsc_kscrw_i_isStackOverflow(const RSC_KSCrash_SentryContext *const crash,
                                 const thread_t thread) {
    RSC_STRUCT_MCONTEXT_L concreteMachineContext;
    RSC_STRUCT_MCONTEXT_L *machineContext =
        rsc_kscrw_i_getMachineContext(crash, thread, &concreteMachineContext);
    if (machineContext == NULL) {
        return false;
    }

    return rsc_ksbt_isBacktraceTooLong(machineContext,
                                       RSC_kStackOverflowThreshold);
}

// ============================================================================
#pragma mark - Report Writing -
// ============================================================================

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
void rsc_kscrw_i_writeMemoryContents(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const uintptr_t address, int *limit);

void rsc_kscrw_i_writeTraceInfo(const RSC_KSCrash_Context *crashContext,
                                const RSC_KSCrashReportWriter *writer);

bool rsc_kscrw_i_exceedsBufferLen(const size_t length);

void rsc_kscrashreport_writeKSCrashFields(RSC_KSCrash_Context *crashContext,
                                          RSC_KSCrashReportWriter *writer,
                                          const char *const path);

#pragma mark Backtrace

/** Write a backtrace entry to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param info Information about the nearest symbols to the address.
 */
void rsc_kscrw_i_writeBacktraceEntry(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const uintptr_t address, struct rsc_symbolicate_result *info) {
    writer->beginObject(writer, key);
    {
        if (info->image && info->image->header) {
            info->image->inCrashReport = true;
            writer->addUIntegerElement(writer, RSC_KSCrashField_ObjectAddr,
                                       (uintptr_t)info->image->header);
        }
        if (info->image && info->image->name) {
            writer->addStringElement(writer, RSC_KSCrashField_ObjectName,
                                     rsc_ksfulastPathEntry(info->image->name));
        }
        if (info->function_address) {
            writer->addUIntegerElement(writer, RSC_KSCrashField_SymbolAddr,
                                       info->function_address);
        }
        if (info->function_name) {
            writer->addStringElement(writer, RSC_KSCrashField_SymbolName,
                                     info->function_name);
        }
        writer->addUIntegerElement(writer, RSC_KSCrashField_InstructionAddr,
                                   address);
    }
    writer->endContainer(writer);
}

/** Write a backtrace to the report.
 *
 * @param writer The writer to write the backtrace to.
 *
 * @param key The object key, if needed.
 *
 * @param backtrace The backtrace to write.
 *
 * @param backtraceLength Length of the backtrace.
 *
 * @param skippedEntries The number of entries that were skipped before the
 *                       beginning of backtrace.
 */
void rsc_kscrw_i_writeBacktrace(const RSC_KSCrashReportWriter *const writer,
                                const char *const key,
                                const uintptr_t *const backtrace,
                                const int backtraceLength,
                                const int skippedEntries) {
    writer->beginObject(writer, key);
    {
        writer->beginArray(writer, RSC_KSCrashField_Contents);
        {
            if (backtraceLength > 0) {
                struct rsc_symbolicate_result symbolicated[backtraceLength];
                rsc_ksbt_symbolicate(backtrace, symbolicated, backtraceLength,
                                     skippedEntries);

                for (int i = 0; i < backtraceLength; i++) {
                    rsc_kscrw_i_writeBacktraceEntry(writer, NULL, backtrace[i],
                                                    &symbolicated[i]);
                }
            }
        }
        writer->endContainer(writer);
        writer->addIntegerElement(writer, RSC_KSCrashField_Skipped,
                                  skippedEntries);
    }
    writer->endContainer(writer);
}

#pragma mark Stack

/** Write the stack overflow state to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param isStackOverflow If true, the stack has overflowed.
 */
void rsc_kscrw_i_writeStackOverflow(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const RSC_STRUCT_MCONTEXT_L *const machineContext,
    const bool isStackOverflow) {
    uintptr_t sp = rsc_ksmachstackPointer(machineContext);
    if ((void *)sp == NULL) {
        return;
    }

    writer->beginObject(writer, key);
    {
        writer->addBooleanElement(writer, RSC_KSCrashField_Overflow,
                                  isStackOverflow);
    }
    writer->endContainer(writer);
}

#pragma mark Registers

/** Write the contents of all regular registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
void rsc_kscrw_i_writeBasicRegisters(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = rsc_ksmachnumRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = rsc_ksmachregisterName(reg);
            if (registerName == NULL) {
                registerNameBuff[0] = 'r';
                rsc_int64_to_string(reg, registerNameBuff+1);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(
                writer, registerName,
                rsc_ksmachregisterValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write the contents of all exception registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
void rsc_kscrw_i_writeExceptionRegisters(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const RSC_STRUCT_MCONTEXT_L *const machineContext) {
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = rsc_ksmachnumExceptionRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = rsc_ksmachexceptionRegisterName(reg);
            if (registerName == NULL) {
                registerNameBuff[0] = 'r';
                rsc_int64_to_string(reg, registerNameBuff+1);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(
                writer, registerName,
                rsc_ksmachexceptionRegisterValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write all applicable registers.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 *
 * @param isCrashedContext If true, this context represents the crashing thread.
 */
void rsc_kscrw_i_writeRegisters(
    const RSC_KSCrashReportWriter *const writer, const char *const key,
    const RSC_STRUCT_MCONTEXT_L *const machineContext,
    const bool isCrashedContext) {
    writer->beginObject(writer, key);
    {
        rsc_kscrw_i_writeBasicRegisters(writer, RSC_KSCrashField_Basic,
                                        machineContext);
        if (isCrashedContext) {
            rsc_kscrw_i_writeExceptionRegisters(
                writer, RSC_KSCrashField_Exception, machineContext);
        }
    }
    writer->endContainer(writer);
}

#pragma mark Thread-specific

/** Write the message from the `__crash_info` Mach section into the report.
 *
 * @param writer The writer.
 *
 * @param key The object key.
 *
 * @param address The address of the first frame in the backtrace.
 */
void rsc_kscrw_i_writeCrashInfoMessage(const RSC_KSCrashReportWriter *const writer,
                                       const char *key, uintptr_t address) {
    RSC_Mach_Header_Info *image = rsc_mach_headers_image_at_address(address);
    if (!image) {
        RSC_KSLOG_ERROR("Could not locate mach header info");
        return;
    }
    const char *message = rsc_mach_headers_get_crash_info_message(image);
    if (message) {
        writer->addStringElement(writer, key, message);
    }
}

/** Write information about a thread to the report.
 *
 * @param writer The writer.
 * @param key The object key, if needed.
 * @param crash The crash handler context.
 * @param thread The thread to write about.
 * @param index The thread's index relative to all threads.
 */
void rsc_kscrw_i_writeThread(const RSC_KSCrashReportWriter *const writer,
                             const char *const key,
                             const RSC_KSCrash_SentryContext *const crash,
                             const thread_t thread,
                             const int index,
                             const integer_t threadRunState) {
    bool isCrashedThread = thread == crash->offendingThread;
    bool isSelfThread = thread == rsc_ksmachthread_self();
    RSC_STRUCT_MCONTEXT_L machineContextBuffer;
    uintptr_t backtraceBuffer[RSC_kMaxBacktraceDepth];
    int backtraceLength = sizeof(backtraceBuffer) / sizeof(*backtraceBuffer);
    int skippedEntries = 0;
    const char* state = rsc_kscrashthread_state_name(threadRunState);
    char name[MAXTHREADNAMESIZE] = {0};

    RSC_STRUCT_MCONTEXT_L *machineContext =
        rsc_kscrw_i_getMachineContext(crash, thread, &machineContextBuffer);

    uintptr_t *backtrace =
        rsc_kscrw_i_getBacktrace(crash, thread, machineContext, backtraceBuffer,
                                 &backtraceLength, &skippedEntries);

    writer->beginObject(writer, key);
    {
        if (backtrace != NULL) {
            rsc_kscrw_i_writeBacktrace(writer, RSC_KSCrashField_Backtrace,
                                       backtrace, backtraceLength,
                                       skippedEntries);
        }
        if (machineContext != NULL && isCrashedThread) {
            rsc_kscrw_i_writeRegisters(writer, RSC_KSCrashField_Registers,
                                       machineContext, isCrashedThread);
        }
        if (state != NULL) {
            writer->addStringElement(writer, RSC_KSCrashField_State, state);
        }
        writer->addIntegerElement(writer, RSC_KSCrashField_Index, index);
        writer->addBooleanElement(writer, RSC_KSCrashField_Crashed,
                                  isCrashedThread);
        writer->addBooleanElement(writer, RSC_KSCrashField_CurrentThread,
                                  isSelfThread);

        // pthread_getname_np() acquires no locks if passed pthread_self() as
        // of libpthread-330.201.1 (macOS 10.14 / iOS 12)
        if (isSelfThread &&
            kCFCoreFoundationVersionNumber >=
            kCFCoreFoundationVersionNumber_iOS_12_0 &&
            !pthread_getname_np(pthread_self(), name, sizeof(name))) {
            writer->addStringElement(writer, RSC_KSCrashField_Name, name);
        }
        if (isCrashedThread && machineContext != NULL) {
            rsc_kscrw_i_writeStackOverflow(writer, RSC_KSCrashField_Stack,
                                           machineContext, skippedEntries > 0);
        }
        if (isCrashedThread && backtrace && backtraceLength) {
            rsc_kscrw_i_writeCrashInfoMessage(writer, RSC_KSCrashField_CrashInfoMessage,
                                              backtrace[0]);
        }
    }
    writer->endContainer(writer);
}

/** Write information about all threads to the report.
 *
 * @param writer The writer.
 * @param key The object key, if needed.
 * @param crash The crash handler context.
 * so additional information about the error can be extracted
 * only the main thread's stacktrace is serialized.
 */
void rsc_kscrw_i_writeAllThreads(const RSC_KSCrashReportWriter *const writer,
                                 const char *const key,
                                 const RSC_KSCrash_SentryContext *const crash) {
    // Fetch info for all threads.
    writer->beginArray(writer, key);
    {
        for (unsigned i = 0; i < crash->allThreadsCount; i++) {
            thread_t thread = crash->allThreads[i];
            integer_t threadRunState = crash->allThreadRunStates[i];
            if (crash->threadTracingEnabled || thread == crash->offendingThread) {
                rsc_kscrw_i_writeThread(writer, NULL, crash, thread, (int) i, threadRunState);
            }
        }
    }
    writer->endContainer(writer);
}

/** Get the index of a thread.
 *
 * @param thread The thread.
 *
 * @return The thread's index, or -1 if it couldn't be determined.
 */
int rsc_kscrw_i_threadIndex(const thread_t thread) {
    int index = -1;
    unsigned threadCount = 0;
    thread_t *threads = rsc_ksmachgetAllThreads(&threadCount);
    if (threads == NULL) {
        return -1;
    }

    for (unsigned i = 0; i < threadCount; i++) {
        if (threads[i] == thread) {
            index = (int)i;
            break;
        }
    }

    rsc_ksmachfreeThreads(threads, threadCount);

    return index;
}

#pragma mark Global Report Data

/** Write information about a binary image to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param img Cached info about the binary image.
 */
void rsc_kscrw_i_writeBinaryImage(const RSC_KSCrashReportWriter *const writer,
                                  const char *const key,
                                  const RSC_Mach_Header_Info *img)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, RSC_KSCrashField_ImageAddress, (uintptr_t)img->header);
        writer->addUIntegerElement(writer, RSC_KSCrashField_ImageVmAddress,          img->imageVmAddr);
        writer->addUIntegerElement(writer, RSC_KSCrashField_ImageSize,               img->imageSize);
        writer->addStringElement(writer, RSC_KSCrashField_Name,                      img->name);
        writer->addUUIDElement(writer, RSC_KSCrashField_UUID,                        img->uuid);
        writer->addIntegerElement(writer, RSC_KSCrashField_CPUType,                  img->header->cputype);
        writer->addIntegerElement(writer, RSC_KSCrashField_CPUSubType,               img->header->cpusubtype);
    }
    writer->endContainer(writer);
}

/** Write information about all images to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
void rsc_kscrw_i_writeBinaryImages(const RSC_KSCrashReportWriter *const writer,
                                   const char *const key)
{
    writer->beginArray(writer, key);
    {
        for (RSC_Mach_Header_Info *img = rsc_mach_headers_get_images(); img != NULL; img = atomic_load(&img->next)) {
            if (img->inCrashReport) {
                rsc_kscrw_i_writeBinaryImage(writer, NULL, img);
            }
        }
    }
    writer->endContainer(writer);
}

/** Write information about system memory to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
void rsc_kscrw_i_writeMemoryInfo(const RSC_KSCrashReportWriter *const writer,
                                 const char *const key) {
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, RSC_KSCrashField_Free,
                                   rsc_runContext->hostMemoryFree);
    }
    writer->endContainer(writer);
}

void rsc_kscrw_i_writeDiskInfo(const RSC_KSCrashReportWriter *const writer,
                               const char *const key,
                               const char *const path) {
    uint64_t freeDisk, size;
    if (!rsc_ksfuStatfs(path, &freeDisk, &size)) {
        return;
    }
    writer->beginObject(writer, key);
    {
        rsc_kscrw_i_addUIntegerElement(writer, RSC_KSCrashField_Free, freeDisk);
        rsc_kscrw_i_addUIntegerElement(writer, RSC_KSCrashField_Size, size);
    }
    writer->endContainer(writer);
}

/** Write information about the error leading to the crash to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
void rsc_kscrw_i_writeError(const RSC_KSCrashReportWriter *const writer,
                            const char *const key,
                            const RSC_KSCrash_SentryContext *const crash) {
    int machExceptionType = 0;
    int64_t machCode = 0;
    int64_t machSubCode = 0;
    int sigNum = 0;
    int sigCode = 0;
    const char *exceptionName = NULL;
    const char *crashReason = NULL;

    // Gather common info.
    switch (crash->crashType) {
    case RSC_KSCrashTypeMachException:
        machExceptionType = crash->mach.type;
        machCode = crash->mach.code;
        if (machCode == KERN_PROTECTION_FAILURE && crash->isStackOverflow) {
            // A stack overflow should return KERN_INVALID_ADDRESS, but
            // when a stack blasts through the guard pages at the top of the
            // stack, it generates KERN_PROTECTION_FAILURE. Correct for this.
            machCode = KERN_INVALID_ADDRESS;
        }
        machSubCode = crash->mach.subcode;

        sigNum =
            rsc_kssignal_signalForMachException(machExceptionType, machCode);
        break;
    case RSC_KSCrashTypeCPPException:
        machExceptionType = EXC_CRASH;
        sigNum = SIGABRT;
        crashReason = crash->crashReason;
        exceptionName = crash->CPPException.name;
        break;
    case RSC_KSCrashTypeNSException:
        machExceptionType = EXC_CRASH;
        sigNum = SIGABRT;
        exceptionName = crash->NSException.name;
        crashReason = crash->crashReason;
        break;
    case RSC_KSCrashTypeSignal:
        sigNum = crash->signal.signalInfo->si_signo;
        sigCode = crash->signal.signalInfo->si_code;
        machExceptionType = rsc_kssignal_machExceptionForSignal(sigNum);
        break;
    }

    const char *machExceptionName = rsc_ksmachexceptionName(machExceptionType);
    const char *machCodeName = machCode == 0 ? NULL :
        rsc_ksmachkernelReturnCodeName((kern_return_t)machCode);
    const char *sigName = rsc_kssignal_signalName(sigNum);
    const char *sigCodeName = rsc_kssignal_signalCodeName(sigNum, sigCode);

    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, RSC_KSCrashField_Address,
                                   crash->faultAddress);

        if (crashReason != NULL) {
            writer->addStringElement(writer, RSC_KSCrashField_Reason,
                                     crashReason);
        }


        // Gather specific info.
        switch (crash->crashType) {
        case RSC_KSCrashTypeMachException:
            writer->beginObject(writer, RSC_KSCrashField_Mach);
            {
                char buffer[20] = "0x";
                
                writer->addUIntegerElement(writer, RSC_KSCrashField_Exception,
                                           (unsigned)machExceptionType);
                if (machExceptionName != NULL) {
                    writer->addStringElement(writer, RSC_KSCrashField_ExceptionName,
                                             machExceptionName);
                }
                
                rsc_uint64_to_hex((uint64_t)machCode, buffer+2, 0);
                writer->addStringElement(writer, RSC_KSCrashField_Code, buffer);
                
                if (machCodeName != NULL) {
                    writer->addStringElement(writer, RSC_KSCrashField_CodeName,
                                             machCodeName);
                }
                
                rsc_uint64_to_hex((uint64_t)machSubCode, buffer+2, 0);
                writer->addStringElement(writer, RSC_KSCrashField_Subcode, buffer);
            }
            writer->endContainer(writer);
            writer->addStringElement(writer, RSC_KSCrashField_Type,
                                     RSC_KSCrashExcType_Mach);
            break;

        case RSC_KSCrashTypeCPPException: {
            writer->addStringElement(writer, RSC_KSCrashField_Type,
                                     RSC_KSCrashExcType_CPPException);
            writer->beginObject(writer, RSC_KSCrashField_CPPException);
            {
                writer->addStringElement(writer, RSC_KSCrashField_Name,
                                         exceptionName);
            }
            writer->endContainer(writer);
            break;
        }
        case RSC_KSCrashTypeNSException: {
            writer->addStringElement(writer, RSC_KSCrashField_Type,
                                     RSC_KSCrashExcType_NSException);
            writer->beginObject(writer, RSC_KSCrashField_NSException);
            {
                writer->addStringElement(writer, RSC_KSCrashField_Name,
                                         exceptionName);
                if (crash->NSException.userInfo) {
                    writer->addJSONElement(writer, RSC_KSCrashField_UserInfo,
                                           crash->NSException.userInfo);
                }
            }
            writer->endContainer(writer);
            break;
        }
        case RSC_KSCrashTypeSignal:
            writer->beginObject(writer, RSC_KSCrashField_Signal);
            {
                writer->addUIntegerElement(writer, RSC_KSCrashField_Signal,
                                           (unsigned)sigNum);
                if (sigName != NULL) {
                    writer->addStringElement(writer, RSC_KSCrashField_Name,
                                             sigName);
                }
                writer->addUIntegerElement(writer, RSC_KSCrashField_Code,
                                           (unsigned)sigCode);
                if (sigCodeName != NULL) {
                    writer->addStringElement(writer, RSC_KSCrashField_CodeName,
                                             sigCodeName);
                }
            }
            writer->endContainer(writer);
            writer->addStringElement(writer, RSC_KSCrashField_Type,
                                     RSC_KSCrashExcType_Signal);
            break;
        }
    }
    writer->endContainer(writer);
}

/** Write information about app runtime, etc to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param state The persistent crash handler state.
 */
void rsc_kscrw_i_writeAppStats(const RSC_KSCrashReportWriter *const writer,
                               const char *const key,
                               RSC_KSCrash_State *state) {
    writer->beginObject(writer, key);
    {
        writer->addBooleanElement(writer, RSC_KSCrashField_AppInFG,
                                  state->applicationIsInForeground);
        writer->addFloatingPointElement(writer,
                                        RSC_KSCrashField_ActiveTimeSinceLaunch,
                                        state->foregroundDurationSinceLaunch);
        writer->addFloatingPointElement(writer,
                                        RSC_KSCrashField_BGTimeSinceLaunch,
                                        state->backgroundDurationSinceLaunch);
    }
    writer->endContainer(writer);
}

/** Write information about this process.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
void rsc_kscrw_i_writeProcessState(const RSC_KSCrashReportWriter *const writer,
                                   const char *const key) {
    writer->beginObject(writer, key);
    {
    }
    writer->endContainer(writer);
}

/** Write basic report information.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param type The report type.
 *
 * @param reportID The report ID.
 */
void rsc_kscrw_i_writeReportInfo(const RSC_KSCrashReportWriter *const writer,
                                 const char *const key, const char *const type,
                                 const char *const reportID,
                                 const char *const processName) {
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, RSC_KSCrashField_Version,
                                 RSC_KSCRASH_REPORT_VERSION);
        writer->addStringElement(writer, RSC_KSCrashField_ID, reportID);
        writer->addStringElement(writer, RSC_KSCrashField_ProcessName,
                                 processName);
        writer->addIntegerElement(writer, RSC_KSCrashField_Timestamp,
                                  time(NULL));
        // gettimeofday() is not documented async-signal safe in the sigaction
        // man page, but times() is and its implementation calls gettimeofday()
        // so it's reasonable to assume that it is in fact safe.
        struct timeval t;
        if (!gettimeofday(&t, NULL)) {
            writer->addIntegerElement(writer, RSC_KSCrashField_Timestamp_Millis,
                                      (long long)t.tv_sec * 1000 +
                                      (long long)t.tv_usec / 1000);
        }
        writer->addStringElement(writer, RSC_KSCrashField_Type, type);
    }
    writer->endContainer(writer);
}

#pragma mark Setup

/** Prepare a report writer for use.
 *
 * @param writer The writer to prepare.
 *
 * @param context JSON writer contextual information.
 */
void rsc_kscrw_i_prepareReportWriter(RSC_KSCrashReportWriter *const writer,
                                     RSC_KSJSONEncodeContext *const context) {
    writer->addBooleanElement = rsc_kscrw_i_addBooleanElement;
    writer->addFloatingPointElement = rsc_kscrw_i_addFloatingPointElement;
    writer->addIntegerElement = rsc_kscrw_i_addIntegerElement;
    writer->addUIntegerElement = rsc_kscrw_i_addUIntegerElement;
    writer->addStringElement = rsc_kscrw_i_addStringElement;
    writer->addTextFileElement = rsc_kscrw_i_addTextFileElement;
    writer->addJSONFileElement = rsc_kscrw_i_addJSONElementFromFile;
    writer->addDataElement = rsc_kscrw_i_addDataElement;
    writer->beginDataElement = rsc_kscrw_i_beginDataElement;
    writer->appendDataElement = rsc_kscrw_i_appendDataElement;
    writer->endDataElement = rsc_kscrw_i_endDataElement;
    writer->addUUIDElement = rsc_kscrw_i_addUUIDElement;
    writer->addJSONElement = rsc_kscrw_i_addJSONElement;
    writer->beginObject = rsc_kscrw_i_beginObject;
    writer->beginArray = rsc_kscrw_i_beginArray;
    writer->endContainer = rsc_kscrw_i_endContainer;
    writer->context = context;
}

/** Open the crash report file.
 *
 * @param path The path to the file.
 *
 * @return The file descriptor, or -1 if an error occurred.
 */
int rsc_kscrw_i_openCrashReportFile(const char *const path) {
    int fd = open(path, O_RDWR | O_CREAT | O_EXCL, 0644);
    if (fd < 0) {
        RSC_KSLOG_ERROR("Could not open crash report file %s: %s", path,
                        strerror(errno));
    }
    return fd;
}

/** Record whether the crashed thread had a stack overflow or not.
 *
 * @param crashContext the context.
 */
void rsc_kscrw_i_updateStackOverflowStatus(
    RSC_KSCrash_Context *const crashContext) {
    // TODO: This feels weird. Shouldn't be mutating the context.
    if (rsc_kscrw_i_isStackOverflow(&crashContext->crash,
                                    crashContext->crash.offendingThread)) {
        RSC_KSLOG_TRACE("Stack overflow detected.");
        crashContext->crash.isStackOverflow = true;
    }
}

// ============================================================================
#pragma mark - Main API -
// ============================================================================

void rsc_kscrashreport_writeMinimalReport(
    RSC_KSCrash_Context *const crashContext, const char *const path) {
    RSC_KSLOG_INFO("Writing minimal crash report to %s", path);

    int fd = rsc_kscrw_i_openCrashReportFile(path);
    if (fd < 0) {
        return;
    }

    rsc_kscrw_i_updateStackOverflowStatus(crashContext);

    RSC_KSFile file;
    char buffer[512];
    RSC_KSFileInit(&file, fd, buffer, sizeof(buffer) / sizeof(*buffer));

    RSC_KSJSONEncodeContext jsonContext;
    jsonContext.userData = &file;
    RSC_KSCrashReportWriter concreteWriter;
    RSC_KSCrashReportWriter *writer = &concreteWriter;
    rsc_kscrw_i_prepareReportWriter(writer, &jsonContext);

    rsc_ksjsonbeginEncode(rsc_getJsonContext(writer), false,
                          rsc_kscrw_i_addJSONData, &file);

    writer->beginObject(writer, RSC_KSCrashField_Report);
    {
        rsc_kscrw_i_writeReportInfo(
            writer, RSC_KSCrashField_Report, RSC_KSCrashReportType_Minimal,
            crashContext->config.crashID, crashContext->config.processName);

        writer->beginObject(writer, RSC_KSCrashField_Crash);
        {
            rsc_kscrw_i_writeThread(
                writer, RSC_KSCrashField_CrashedThread, &crashContext->crash,
                crashContext->crash.offendingThread,
                0,
                rsc_kscrw_i_threadIndex(crashContext->crash.offendingThread));
            rsc_kscrw_i_writeError(writer, RSC_KSCrashField_Error,
                                   &crashContext->crash);
        }
        writer->endContainer(writer);

        RSC_Mach_Header_Info *image = rsc_mach_headers_get_self_image();
        if (image) {
            writer->beginArray(writer, RSC_KSCrashField_BinaryImages);
            rsc_kscrw_i_writeBinaryImage(writer, NULL, image);
            writer->endContainer(writer);
        }
    }
    writer->endContainer(writer);

    rsc_ksjsonendEncode(rsc_getJsonContext(writer));

    RSC_KSFileFlush(&file);
    close(fd);
}

void rsc_kscrashreport_writeStandardReport(
    RSC_KSCrash_Context *const crashContext, const char *const path) {
    RSC_KSLOG_INFO("Writing crash report to %s", path);

    int fd = rsc_kscrw_i_openCrashReportFile(path);
    if (fd < 0) {
        return;
    }

    rsc_kscrw_i_updateStackOverflowStatus(crashContext);

    RSC_KSFile file;
    char buffer[4096];
    RSC_KSFileInit(&file, fd, buffer, sizeof(buffer) / sizeof(*buffer));

    RSC_KSJSONEncodeContext jsonContext;
    jsonContext.userData = &file;
    RSC_KSCrashReportWriter concreteWriter;
    RSC_KSCrashReportWriter *writer = &concreteWriter;
    rsc_kscrw_i_prepareReportWriter(writer, &jsonContext);

    rsc_ksjsonbeginEncode(rsc_getJsonContext(writer), false,
                          rsc_kscrw_i_addJSONData, &file);

    writer->beginObject(writer, RSC_KSCrashField_Report);
    {
        rsc_kscrw_i_writeReportInfo(
                writer, RSC_KSCrashField_Report, RSC_KSCrashReportType_Standard,
                crashContext->config.crashID, crashContext->config.processName);

        rsc_kscrashreport_writeKSCrashFields(crashContext, writer, path);

        if (crashContext->config.onCrashNotify != NULL) {
            // NOTE: The deny list for RSC_KSCrashField_UserAtCrash children in RSCrashReporterEvent.m
            // should be updated when adding new fields here

            // Write handled exception report info
            writer->beginObject(writer, RSC_KSCrashField_UserAtCrash);
            crashContext->config.onCrashNotify(writer);
            writer->endContainer(writer);
        }
    }
    writer->endContainer(writer);

    rsc_ksjsonendEncode(rsc_getJsonContext(writer));

    RSC_KSFileFlush(&file);
    close(fd);
}

void rsc_kscrashreport_writeKSCrashFields(RSC_KSCrash_Context *crashContext,
                                          RSC_KSCrashReportWriter *writer,
                                          const char *const path) {

    rsc_kscrw_i_writeProcessState(writer, RSC_KSCrashField_ProcessState);

    if (crashContext->config.systemInfoJSON != NULL) {
        rsc_kscrw_i_addJSONElement(writer, RSC_KSCrashField_System,
                crashContext->config.systemInfoJSON);
    }

    writer->beginObject(writer, RSC_KSCrashField_SystemAtCrash);
    {
        RSCRunContextUpdateMemory();
        rsc_kscrw_i_writeMemoryInfo(writer, RSC_KSCrashField_Memory);
        rsc_kscrw_i_writeAppStats(writer, RSC_KSCrashField_AppStats,
                &crashContext->state);
        rsc_kscrw_i_writeDiskInfo(writer, RSC_KSCrashField_Disk, path);
    }
    writer->endContainer(writer);

    rsc_kscrw_i_writeTraceInfo(crashContext, writer);
}

void rsc_kscrw_i_writeTraceInfo(const RSC_KSCrash_Context *crashContext,
                                const RSC_KSCrashReportWriter *writer) {
    const RSC_KSCrash_SentryContext *crash = &crashContext->crash;

    writer->beginObject(writer, RSC_KSCrashField_Crash);
    {
        rsc_kscrw_i_writeError(writer, RSC_KSCrashField_Error, crash);
        rsc_kscrw_i_writeAllThreads(writer, RSC_KSCrashField_Threads, crash);
    }
    writer->endContainer(writer);

    // Called *after* writeAllThreads() so that we know which images to include
    rsc_kscrw_i_writeBinaryImages(writer, RSC_KSCrashField_BinaryImages);
}
