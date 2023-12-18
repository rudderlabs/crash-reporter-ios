//
//  RSCEventUploadKSCrashReportOperation.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 RSCrashReporter Inc. All rights reserved.
//

#import "RSCEventUploadFileOperation.h"

#import "RSCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A concrete operation class for reading a KSCrashReport from disk, converting it into a RSCrashReporterEvent, and uploading.
 */
RSC_OBJC_DIRECT_MEMBERS
@interface RSCEventUploadKSCrashReportOperation : RSCEventUploadFileOperation

@end

NS_ASSUME_NONNULL_END
