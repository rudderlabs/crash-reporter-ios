//
//  RSC_KSCrashState.c
//
//  Created by Karl Stenerud on 2012-02-05.
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

#import "RSC_KSCrashState.h"

#import "RSCJSONSerialization.h"
#import "RSCRunContext.h"
#import "RSC_KSFile.h"
#import "RSC_KSJSONCodec.h"
#import "RSC_KSLogger.h"
#import "RSC_KSMach.h"
#import "RSC_KSSystemInfo.h"
#import "RSCUIKit.h"

#import <errno.h>
#import <fcntl.h>
#import <mach/mach_time.h>
#import <stdlib.h>
#import <unistd.h>

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define RSC_kFormatVersion 1

#define RSC_kKeyFormatVersion "version"
#define RSC_kKeyCrashedLastLaunch "crashedLastLaunch"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Location where stat file is stored. */
static const char *rsc_g_stateFilePath;

/** Current state. */
static RSC_KSCrash_State *rsc_g_state;

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

/** Callback for adding JSON data.
 */
static
int rsc_kscrashstate_i_addJSONData(const char *const data, const size_t length,
                                   void *const userData) {
    bool success = RSC_KSFileWrite(userData, data, length);
    return success ? RSC_KSJSON_OK : RSC_KSJSON_ERROR_CANNOT_ADD_DATA;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Load the persistent state portion of a crash context.
 *
 * @param context The context to load into.
 *
 * @param path The path to the file to read.
 *
 * @return true if the operation was successful.
 */
bool rsc_kscrashstate_i_loadState(RSC_KSCrash_State *const context,
                                  const char *const path) {
    NSString *file = path ? @(path) : nil;
    if (!file) {
        rsc_log_err(@"Invalid path: %s", path);
        return false;
    }
    NSError *error;
    NSDictionary *dict = RSCJSONDictionaryFromFile(file, 0, &error);
    if (!dict) {
        if (!(error.domain == NSCocoaErrorDomain &&
              error.code == NSFileReadNoSuchFileError)) {
            rsc_log_err(@"%s: Could not load file: %@", path, error);
        }
        return false;
    }
    if (![dict[@ RSC_kKeyFormatVersion] isEqual:@ RSC_kFormatVersion]) {
        rsc_log_err(@"Version mismatch");
        return false;
    }
    context->crashedLastLaunch = [dict[@ RSC_kKeyCrashedLastLaunch] boolValue];
    return true;
}

/** Save the persistent state portion of a crash context.
 *
 * @param state The context to save from.
 *
 * @param path The path to the file to create.
 *
 * @return true if the operation was successful.
 */
bool rsc_kscrashstate_i_saveState(const RSC_KSCrash_State *const state,
                                  const char *const path) {

    // Opening an existing file fails under NSFileProtectionComplete*
    unlink(path);

    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        rsc_log_err(@"Could not open file %s for writing: %s", path, strerror(errno));
        return false;
    }

    RSC_KSFile file;
    char buffer[256];
    RSC_KSFileInit(&file, fd, buffer, sizeof(buffer) / sizeof(*buffer));

    RSC_KSJSONEncodeContext JSONContext;
    rsc_ksjsonbeginEncode(&JSONContext, false, rsc_kscrashstate_i_addJSONData,
                          &file);

    int result;
    if ((result = rsc_ksjsonbeginObject(&JSONContext, NULL)) != RSC_KSJSON_OK) {
        goto done;
    }
    if ((result = rsc_ksjsonaddIntegerElement(
             &JSONContext, RSC_kKeyFormatVersion, RSC_kFormatVersion)) !=
        RSC_KSJSON_OK) {
        goto done;
    }
    // Record this launch crashed state into "crashed last launch" field.
    if ((result = rsc_ksjsonaddBooleanElement(
             &JSONContext, RSC_kKeyCrashedLastLaunch,
             state->crashedThisLaunch)) != RSC_KSJSON_OK) {
        goto done;
    }
    result = rsc_ksjsonendEncode(&JSONContext);

done:
    RSC_KSFileFlush(&file);
    close(fd);

    if (result != RSC_KSJSON_OK) {
        rsc_log_err(@"%s: %s", path, rsc_ksjsonstringForError(result));
        return false;
    }
    return true;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

bool rsc_kscrashstate_init(const char *const stateFilePath,
                           RSC_KSCrash_State *const state) {
    rsc_g_stateFilePath = stateFilePath;
    rsc_g_state = state;

    uint64_t timeNow = mach_absolute_time();
    memset(state, 0, sizeof(*state));
    rsc_kscrashstate_i_loadState(state, stateFilePath);
    state->appLaunchTime = timeNow;
    state->lastUpdateDurationsTime = timeNow;
    state->applicationIsInForeground = rsc_runContext->isForeground;

    return rsc_kscrashstate_i_saveState(state, stateFilePath);
}

void rsc_kscrashstate_notifyAppInForeground(const bool isInForeground) {
    RSC_KSCrash_State *const state = rsc_g_state;

    if (state->applicationIsInForeground == isInForeground) {
        return;
    }
    state->applicationIsInForeground = isInForeground;
    uint64_t timeNow = mach_absolute_time();
    double duration = rsc_ksmachtimeDifferenceInSeconds(
        timeNow, state->lastUpdateDurationsTime);
    if (isInForeground) {
        state->backgroundDurationSinceLaunch += duration;
    } else {
        state->foregroundDurationSinceLaunch += duration;
    }
    state->lastUpdateDurationsTime = timeNow;
}

void rsc_kscrashstate_notifyAppCrash(void) {
    rsc_kscrashstate_updateDurationStats();
    rsc_g_state->crashedThisLaunch = YES;
    rsc_kscrashstate_i_saveState(rsc_g_state, rsc_g_stateFilePath);
}

void rsc_kscrashstate_updateDurationStats(void) {
    uint64_t timeNow = mach_absolute_time();
    const double duration = rsc_ksmachtimeDifferenceInSeconds(
        timeNow, rsc_g_state->lastUpdateDurationsTime ?: rsc_g_state->appLaunchTime);
    if (rsc_g_state->applicationIsInForeground) {
        rsc_g_state->foregroundDurationSinceLaunch += duration;
    } else {
        rsc_g_state->backgroundDurationSinceLaunch += duration;
    }
    rsc_g_state->lastUpdateDurationsTime = timeNow;
}

const RSC_KSCrash_State *rsc_kscrashstate_currentState(void) {
    return rsc_g_state;
}
