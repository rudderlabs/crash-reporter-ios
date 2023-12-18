//
//  RSC_KSCrashType.h
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

#ifndef HDR_RSC_KSCrashType_h
#define HDR_RSC_KSCrashType_h

#include <CoreFoundation/CoreFoundation.h>

/** Different ways an application can crash:
 * - Mach kernel exception
 * - Fatal signal
 * - Uncaught C++ exception
 * - Uncaught Objective-C NSException
 */


typedef CF_ENUM(unsigned, RSC_KSCrashType) {
    RSC_KSCrashTypeMachException = 0x01,
    RSC_KSCrashTypeSignal = 0x02,
    RSC_KSCrashTypeCPPException = 0x04,
    RSC_KSCrashTypeNSException = 0x08,
};

#define RSC_KSCrashTypeAll                                                     \
    (RSC_KSCrashTypeMachException | RSC_KSCrashTypeSignal |                    \
     RSC_KSCrashTypeCPPException | RSC_KSCrashTypeNSException)

#define RSC_KSCrashTypeDebuggerUnsafe                                          \
    (RSC_KSCrashTypeMachException | RSC_KSCrashTypeNSException)

#define RSC_KSCrashTypeAsyncSafe                                               \
    (RSC_KSCrashTypeMachException | RSC_KSCrashTypeSignal)

/** Crash types that are safe to enable in a debugger. */
#define RSC_KSCrashTypeDebuggerSafe                                            \
    (RSC_KSCrashTypeAll & (~RSC_KSCrashTypeDebuggerUnsafe))

/** It is safe to catch these kinds of crashes in a production environment.
 * All other crash types should be considered experimental.
 */
#define RSC_KSCrashTypeProductionSafe RSC_KSCrashTypeAll

#define RSC_KSCrashTypeNone 0

#endif // HDR_KSCrashType_h
