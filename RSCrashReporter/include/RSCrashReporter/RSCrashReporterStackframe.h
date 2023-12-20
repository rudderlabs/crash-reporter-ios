//
//  RSCrashReporterStackframe.h
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <RSCrashReporter/RSCrashReporterDefines.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * RSCrashReporterStackframeType NS_TYPED_ENUM;

RSCRASHREPORTER_EXTERN RSCrashReporterStackframeType const RSCrashReporterStackframeTypeCocoa;

/**
 * Represents a single stackframe from a stacktrace.
 */
RSCRASHREPORTER_EXTERN
@interface RSCrashReporterStackframe : NSObject

/**
 * The method name of the stackframe
 */
@property (copy, nullable, nonatomic) NSString *method;

/**
 * The Mach-O file used by the stackframe
 */
@property (copy, nullable, nonatomic) NSString *machoFile;

/**
 * A UUID identifying the Mach-O file used by the stackframe
 */
@property (copy, nullable, nonatomic) NSString *machoUuid;

/**
 * The stack frame address
 */
@property (strong, nullable, nonatomic) NSNumber *frameAddress;

/**
 * The Mach-O file's desired base virtual memory address
 */
@property (strong, nullable, nonatomic) NSNumber *machoVmAddress;

/**
 * The address of the stackframe symbol
 */
@property (strong, nullable, nonatomic) NSNumber *symbolAddress;

/**
 * The address at which the Mach-O file is mapped into memory
 */
@property (strong, nullable, nonatomic) NSNumber *machoLoadAddress;

/**
 * True if `frameAddress` is equal to the value of the program counter register.
 */
@property (nonatomic) BOOL isPc;

/**
 * True if `frameAddress` is equal to the value of the link register.
 */
@property (nonatomic) BOOL isLr;

/**
 * The type of the stack frame, if it differs from that of the containing error or event.
 */
@property (copy, nullable, nonatomic) RSCrashReporterStackframeType type;

/**
 * Creates an array of stackframe objects representing the provided call stack.
 *
 * @param callStackReturnAddresses An array containing the call stack return addresses, as returned by
 * `NSThread.callStackReturnAddresses` or `NSException.callStackReturnAddresses`.
 */
+ (NSArray<RSCrashReporterStackframe *> *)stackframesWithCallStackReturnAddresses:(NSArray<NSNumber *> *)callStackReturnAddresses;

/**
 * Creates an array of stackframe objects representing the provided call stack.
 *
 * @param callStackSymbols An array containing the call stack symbols, as returned by `NSThread.callStackSymbols`.
 * Each element should be in a format determined by the `backtrace_symbols()` function.

 */
+ (nullable NSArray<RSCrashReporterStackframe *> *)stackframesWithCallStackSymbols:(NSArray<NSString *> *)callStackSymbols;

@end

NS_ASSUME_NONNULL_END
