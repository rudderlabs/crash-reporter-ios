//
//  RSC_KSCrashSentry_CPPException.h
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

#ifndef HDR_RSC_KSCrashSentry_CPPException_h
#define HDR_RSC_KSCrashSentry_CPPException_h

#ifdef __cplusplus
extern "C" {
#endif

#include "RSC_KSCrashSentry.h"

/** Install the C++ exception handler.
 *
 * @param context Contextual information for the crash handler.
 *
 * @return true if installation was succesful.
 */
bool rsc_kscrashsentry_installCPPExceptionHandler(
    RSC_KSCrash_SentryContext *context);

/** Uninstall the C++ exception handler.
 */
void rsc_kscrashsentry_uninstallCPPExceptionHandler(void);

#ifdef __cplusplus
}
#endif

#endif // HDR_KSCrashSentry_CPPException_h
