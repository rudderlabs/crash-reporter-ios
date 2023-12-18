//
//  RSC_KSLogger.h
//
//  Created by Karl Stenerud on 11-06-25.
//
//  Copyright (c) 2011 Karl Stenerud. All rights reserved.
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

#ifndef HDR_RSC_KSLogger_h
#define HDR_RSC_KSLogger_h

#ifdef __cplusplus
extern "C" {
#endif

#include <RSCrashReporter/RSCrashReporterDefines.h>

#include "RSCrashReporterLogger.h"

/**
 * Enables low-level logging.
 *
 * Keep this disabled in production as it increases the binary size.
 */
#ifndef RSC_KSLOG_ENABLED
#define RSC_KSLOG_ENABLED 0
#endif

/**
 * RSC_KSLogger
 * ========
 *
 * Prints log entries to the console consisting of:
 * - Level (Error, Warn, Info, Debug, Trace)
 * - File
 * - Line
 * - Function
 * - Message
 *
 * Allows setting the minimum logging level in the preprocessor.
 *
 *
 * =====
 * USAGE
 * =====
 *
 * Set the log level in your "Preprocessor Macros" build setting. You may choose
 * TRACE, DEBUG, INFO, WARN, ERROR. If nothing is set, it defaults to INFO.
 *
 * Example: RSC_KSLogger_Level=WARN
 *
 * Anything below the level specified for RSC_KSLogger_Level will not be
 * compiled or printed.
 *
 *
 * Next, include the header file:
 *
 * #include "RSC_KSLogger.h"
 *
 *
 * Next, call the logger functions from your code:
 *
 * Code:
 *    RSC_KSLOG_ERROR("Some error message");
 *
 * Prints:
 *    ERROR: some_file.c:21: some_function(): Some error message
 *
 *
 * The "BASIC" versions of the macros behave exactly like printf(), except they
 * respect the RSC_KSLogger_Level setting:
 *
 * Code:
 *    RSC_KSLOGBASIC_ERROR("A basic log entry");
 *
 * Prints:
 *    A basic log entry
 *
 *
 * =============
 * LOCAL LOGGING
 * =============
 *
 * You can control logging messages at the local file level using the
 * "KSLogger_LocalLevel" define. Note that it must be defined BEFORE
 * including RSC_KSLogger.h
 *
 * The RSC_KSLOG_XX() and RSC_KSLOGBASIC_XX() macros will print out based on the
 * LOWER of RSC_KSLogger_Level and RSC_KSLogger_LocalLevel, so if
 * RSC_KSLogger_Level is DEBUG and RSC_KSLogger_LocalLevel is TRACE, it will
 * print all the way down to the trace level for the local file where
 * RSC_KSLogger_LocalLevel was defined, and to the debug level everywhere else.
 *
 * Example:
 *
 * // RSC_KSLogger_LocalLevel, if defined, MUST come BEFORE including
 * RSC_KSLogger.h #define RSC_KSLogger_LocalLevel TRACE #import "RSC_KSLogger.h"
 *
 *
 * ===============
 * IMPORTANT NOTES
 * ===============
 *
 * The C logger changes its behavior depending on the value of the preprocessor
 * define RSC_KSLogger_CBufferSize.
 *
 * If RSC_KSLogger_CBufferSize is > 0, the C logger will behave in an async-safe
 * manner, calling write() instead of printf(). Any log messages that exceed the
 * length specified by RSC_KSLogger_CBufferSize will be truncated.
 *
 * If RSC_KSLogger_CBufferSize == 0, the C logger will use printf(), and there
 * will be no limit on the log message length.
 *
 * RSC_KSLogger_CBufferSize can only be set as a preprocessor define, and will
 * default to 1024 if not specified during compilation.
 */

// ============================================================================
#pragma mark - (internal) -
// ============================================================================

#include <stdbool.h>
#include <sys/cdefs.h>

void rsc_i_kslog_logC(const char *level, const char *file, int line,
                      const char *function, const char *fmt, ...)
                                                __printflike(5, 6);

RSCRASHREPORTER_EXTERN
void rsc_i_kslog_logCBasic(const char *fmt, ...) __printflike(1, 2);

#define i_KSLOG_FULL rsc_i_kslog_logC
#define i_KSLOG_BASIC rsc_i_kslog_logCBasic

/* Back up any existing defines by the same name */
#ifdef NONE
#define RSC_KSLOG_BAK_NONE NONE
#undef NONE
#endif
#ifdef ERROR
#define RSC_KSLOG_BAK_ERROR ERROR
#undef ERROR
#endif
#ifdef WARN
#define RSC_KSLOG_BAK_WARN WARN
#undef WARN
#endif
#ifdef INFO
#define RSC_KSLOG_BAK_INFO INFO
#undef INFO
#endif
#ifdef DEBUG
#define RSC_KSLOG_BAK_DEBUG DEBUG
#undef DEBUG
#endif
#ifdef TRACE
#define RSC_KSLOG_BAK_TRACE TRACE
#undef TRACE
#endif

#define RSC_KSLogger_Level_None 0
#define RSC_KSLogger_Level_Error 10
#define RSC_KSLogger_Level_Warn 20
#define RSC_KSLogger_Level_Info 30
#define RSC_KSLogger_Level_Debug 40
#define RSC_KSLogger_Level_Trace 50

#define NONE RSC_KSLogger_Level_None
#define ERROR RSC_KSLogger_Level_Error
#define WARN RSC_KSLogger_Level_Warn
#define INFO RSC_KSLogger_Level_Info
#define DEBUG RSC_KSLogger_Level_Debug
#define TRACE RSC_KSLogger_Level_Trace

#ifndef RSC_KSLogger_LocalLevel
#define RSC_KSLogger_LocalLevel RSC_KSLogger_Level_None
#endif

#if !RSC_KSLOG_ENABLED
#undef RSC_LOG_LEVEL
#define RSC_LOG_LEVEL RSC_KSLogger_Level_None
#undef RSC_KSLogger_LocalLevel
#define RSC_KSLogger_LocalLevel RSC_KSLogger_Level_None
#endif

#define a_KSLOG_FULL(LEVEL, FMT, ...)                                          \
    i_KSLOG_FULL(LEVEL, __FILE__, __LINE__, __func__, FMT, ##__VA_ARGS__)

// ============================================================================
#pragma mark - API -
// ============================================================================

/** Set the filename to log to.
 *
 * @param filename The file to write to (NULL = write to stdout).
 *
 * @param overwrite If true, overwrite the log file.
 */
RSCRASHREPORTER_EXTERN
bool rsc_kslog_setLogFilename(const char *filename, bool overwrite);

/** Tests if the logger would print at the specified level.
 *
 * @param LEVEL The level to test for. One of:
 *            RSC_KSLogger_Level_Error,
 *            RSC_KSLogger_Level_Warn,
 *            RSC_KSLogger_Level_Info,
 *            RSC_KSLogger_Level_Debug,
 *            RSC_KSLogger_Level_Trace,
 *
 * @return TRUE if the logger would print at the specified level.
 */
#define RSC_KSLOG_PRINTS_AT_LEVEL(LEVEL)                                       \
    (RSC_LOG_LEVEL >= LEVEL || RSC_KSLogger_LocalLevel >= LEVEL)

/** Log a message regardless of the log settings.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#define RSC_KSLOG_ALWAYS(FMT, ...) a_KSLOG_FULL("FORCE", FMT, ##__VA_ARGS__)
#define RSC_KSLOGBASIC_ALWAYS(FMT, ...) i_KSLOG_BASIC(FMT, ##__VA_ARGS__)

/** Log an error.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if RSC_KSLOG_PRINTS_AT_LEVEL(RSC_KSLogger_Level_Error)
#define RSC_KSLOG_ERROR(FMT, ...) a_KSLOG_FULL("ERROR", FMT, ##__VA_ARGS__)
#define RSC_KSLOGBASIC_ERROR(FMT, ...) i_KSLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define RSC_KSLOG_ERROR(FMT, ...)
#define RSC_KSLOGBASIC_ERROR(FMT, ...)
#endif

/** Log a warning.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if RSC_KSLOG_PRINTS_AT_LEVEL(RSC_KSLogger_Level_Warn)
#define RSC_KSLOG_WARN(FMT, ...) a_KSLOG_FULL("WARN ", FMT, ##__VA_ARGS__)
#define RSC_KSLOGBASIC_WARN(FMT, ...) i_KSLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define RSC_KSLOG_WARN(FMT, ...)
#define RSC_KSLOGBASIC_WARN(FMT, ...)
#endif

/** Log an info message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if RSC_KSLOG_PRINTS_AT_LEVEL(RSC_KSLogger_Level_Info)
#define RSC_KSLOG_INFO(FMT, ...) a_KSLOG_FULL("INFO ", FMT, ##__VA_ARGS__)
#define RSC_KSLOGBASIC_INFO(FMT, ...) i_KSLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define RSC_KSLOG_INFO(FMT, ...)
#define RSC_KSLOGBASIC_INFO(FMT, ...)
#endif

/** Log a debug message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if RSC_KSLOG_PRINTS_AT_LEVEL(RSC_KSLogger_Level_Debug)
#define RSC_KSLOG_DEBUG(FMT, ...) a_KSLOG_FULL("DEBUG", FMT, ##__VA_ARGS__)
#define RSC_KSLOGBASIC_DEBUG(FMT, ...) i_KSLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define RSC_KSLOG_DEBUG(FMT, ...)
#define RSC_KSLOGBASIC_DEBUG(FMT, ...)
#endif

/** Log a trace message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if RSC_KSLOG_PRINTS_AT_LEVEL(RSC_KSLogger_Level_Trace)
#define RSC_KSLOG_TRACE(FMT, ...) a_KSLOG_FULL("TRACE", FMT, ##__VA_ARGS__)
#define RSC_KSLOGBASIC_TRACE(FMT, ...) i_KSLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define RSC_KSLOG_TRACE(FMT, ...)
#define RSC_KSLOGBASIC_TRACE(FMT, ...)
#endif

// ============================================================================
#pragma mark - (internal) -
// ============================================================================

/* Put everything back to the way we found it. */
#undef ERROR
#ifdef RSC_KSLOG_BAK_ERROR
#define ERROR RSC_KSLOG_BAK_ERROR
#undef RSC_KSLOG_BAK_ERROR
#endif
#undef WARNING
#ifdef RSC_KSLOG_BAK_WARN
#define WARNING RSC_KSLOG_BAK_WARN
#undef RSC_KSLOG_BAK_WARN
#endif
#undef INFO
#ifdef RSC_KSLOG_BAK_INFO
#define INFO RSC_KSLOG_BAK_INFO
#undef RSC_KSLOG_BAK_INFO
#endif
#undef DEBUG
#ifdef RSC_KSLOG_BAK_DEBUG
#define DEBUG RSC_KSLOG_BAK_DEBUG
#undef RSC_KSLOG_BAK_DEBUG
#endif
#undef TRACE
#ifdef RSC_KSLOG_BAK_TRACE
#define TRACE RSC_KSLOG_BAK_TRACE
#undef RSC_KSLOG_BAK_TRACE
#endif

#ifdef __cplusplus
}
#endif

#endif // HDR_KSLogger_h
