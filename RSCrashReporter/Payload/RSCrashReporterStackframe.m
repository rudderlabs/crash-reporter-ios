//
//  RSCrashReporterStackframe.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "RSCrashReporterStackframe+Private.h"

#import "RSCKeys.h"
#import "RSC_KSBacktrace.h"
#import "RSC_KSCrashReportFields.h"
#import "RSC_KSMachHeaders.h"
#import "RSC_Symbolicate.h"
#import "RSCrashReporterCollections.h"
#import "RSCrashReporterLogger.h"

RSCrashReporterStackframeType const RSCrashReporterStackframeTypeCocoa = @"cocoa";


static NSString * _Nullable FormatMemoryAddress(NSNumber * _Nullable address) {
    return address == nil ? nil : [NSString stringWithFormat:@"0x%" PRIxPTR, address.unsignedLongValue];
}


// MARK: -

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterStackframe

static NSDictionary * _Nullable FindImage(NSArray *images, uintptr_t addr) {
    for (NSDictionary *image in images) {
        if ([(NSNumber *)image[@ RSC_KSCrashField_ImageAddress] unsignedLongValue] == addr) {
            return image;
        }
    }
    return nil;
}

+ (RSCrashReporterStackframe *)frameFromJson:(NSDictionary *)json {
    RSCrashReporterStackframe *frame = [RSCrashReporterStackframe new];
    frame.machoFile = RSCDeserializeString(json[RSCKeyMachoFile]);
    frame.method = RSCDeserializeString(json[RSCKeyMethod]);
    frame.isPc = RSCDeserializeNumber(json[RSCKeyIsPC]).boolValue;
    frame.isLr = RSCDeserializeNumber(json[RSCKeyIsLR]).boolValue;
    frame.machoUuid = RSCDeserializeString(json[RSCKeyMachoUUID]);
    frame.machoVmAddress = [self readInt:json key:RSCKeyMachoVMAddress];
    frame.frameAddress = [self readInt:json key:RSCKeyFrameAddress];
    frame.symbolAddress = [self readInt:json key:RSCKeySymbolAddr];
    frame.machoLoadAddress = [self readInt:json key:RSCKeyMachoLoadAddr];
    frame.type = RSCDeserializeString(json[RSCKeyType]);
    frame.codeIdentifier = RSCDeserializeString(json[@"codeIdentifier"]);
    frame.columnNumber = RSCDeserializeNumber(json[@"columnNumber"]);
    frame.file = RSCDeserializeString(json[@"file"]);
    frame.inProject = RSCDeserializeNumber(json[@"inProject"]);
    frame.lineNumber = RSCDeserializeNumber(json[@"lineNumber"]);
    return frame;
}

+ (NSNumber *)readInt:(NSDictionary *)json key:(NSString *)key {
    id obj = json[key];
    if ([obj isKindOfClass:[NSString class]]) {
        return @(strtoul([obj UTF8String], NULL, 16));
    }
    return nil;
}

+ (instancetype)frameFromDict:(NSDictionary<NSString *, id> *)dict withImages:(NSArray<NSDictionary<NSString *, id> *> *)binaryImages {
    NSNumber *frameAddress = dict[@ RSC_KSCrashField_InstructionAddr];
    if (frameAddress.unsignedLongLongValue == 1) {
        // We sometimes get a frame address of 0x1 at the bottom of the call stack.
        // It's not a valid stack frame and causes E2E tests to fail, so should be ignored.
        return nil;
    }

    RSCrashReporterStackframe *frame = [RSCrashReporterStackframe new];
    frame.frameAddress = frameAddress;
    frame.machoFile = dict[@ RSC_KSCrashField_ObjectName]; // last path component
    frame.machoLoadAddress = dict[@ RSC_KSCrashField_ObjectAddr];
    frame.method = dict[@ RSC_KSCrashField_SymbolName];
    frame.symbolAddress = dict[@ RSC_KSCrashField_SymbolAddr];
    frame.isPc = [dict[RSCKeyIsPC] boolValue];
    frame.isLr = [dict[RSCKeyIsLR] boolValue];

    NSDictionary *image = FindImage(binaryImages, (uintptr_t)frame.machoLoadAddress.unsignedLongLongValue);
    if (image != nil) {
        frame.machoFile = image[@ RSC_KSCrashField_Name]; // full path
        frame.machoUuid = image[@ RSC_KSCrashField_UUID];
        frame.machoVmAddress = image[@ RSC_KSCrashField_ImageVmAddress];
    } else if (frame.isPc) {
        // If the program counter's value isn't in any known image, the crash may have been due to a bad function pointer.
        // Ignore these frames to prevent the dashboard grouping on the address.
        return nil;
    } else if (frame.isLr) {
        // Ignore invalid link register frames.
        // For EXC_BREAKPOINT mach exceptions the link register does not contain an instruction address.
        return nil;
    } else if (/* Don't warn for recrash reports */ binaryImages.count > 1) {
        rsc_log_warn(@"RSCrashReporterStackframe: no image found for address %@", FormatMemoryAddress(frame.machoLoadAddress));
    }
    
    return frame;
}

+ (NSArray<RSCrashReporterStackframe *> *)stackframesWithBacktrace:(uintptr_t *)backtrace length:(NSUInteger)length {
    NSMutableArray<RSCrashReporterStackframe *> *frames = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < length; i++) {
        uintptr_t address = backtrace[i];
        if (address == 1) {
            // We sometimes get a frame address of 0x1 at the bottom of the call stack.
            // It's not a valid stack frame and causes E2E tests to fail, so should be ignored.
            continue;
        }
        
        [frames addObject:[[RSCrashReporterStackframe alloc] initWithAddress:address]];
    }
    
    return frames;
}

+ (NSArray<RSCrashReporterStackframe *> *)stackframesWithCallStackReturnAddresses:(NSArray<NSNumber *> *)callStackReturnAddresses {
    NSUInteger length = callStackReturnAddresses.count;
    uintptr_t addresses[length];
    for (NSUInteger i = 0; i < length; i++) {
        addresses[i] = (uintptr_t)callStackReturnAddresses[i].unsignedLongLongValue;
    }
    return [RSCrashReporterStackframe stackframesWithBacktrace:addresses length:length];
}

+ (NSArray<RSCrashReporterStackframe *> *)stackframesWithCallStackSymbols:(NSArray<NSString *> *)callStackSymbols {
    NSString *pattern = (@"^(\\d+)"             // Capture the leading frame number
                         @" +"                  // Skip whitespace
                         @"([\\S ]+?)"          // Image name (may contain spaces)
                         @" +"                  // Skip whitespace
                         @"(0x[0-9a-fA-F]+)"    // Capture the frame address
                         @"("                   // Start optional group
                         @" "                   // Skip whitespace
                         @"(.+)"                // Capture symbol name
                         @" \\+ "               // Skip " + "
                         @"\\d+"                // Instruction offset
                         @")?$"                 // End optional group
                         );
    
    NSError *error;
    NSRegularExpression *regex =
    [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    if (!regex) {
        rsc_log_err(@"%@", error);
        return nil;
    }
    
    NSMutableArray<RSCrashReporterStackframe *> *frames = [NSMutableArray array];
    
    for (NSString *string in callStackSymbols) {
        NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
        if (match.numberOfRanges != 6) {
            continue;
        }
        NSString *imageName = [string substringWithRange:[match rangeAtIndex:2]];
        NSString *frameAddress = [string substringWithRange:[match rangeAtIndex:3]];
        NSRange symbolNameRange = [match rangeAtIndex:5];
        NSString *symbolName = nil;
        if (symbolNameRange.location != NSNotFound) {
            symbolName = [string substringWithRange:symbolNameRange];
        }
        
        uintptr_t address = 0;
        if (frameAddress.UTF8String != NULL) {
            sscanf(frameAddress.UTF8String, "%lx", &address);
        }
        
        RSCrashReporterStackframe *frame = [[RSCrashReporterStackframe alloc] initWithAddress:address];
        frame.machoFile = imageName;
        frame.method = symbolName ?: frameAddress;
        [frames addObject:frame];
    }
    
    return [NSArray arrayWithArray:frames];
}

- (instancetype)initWithAddress:(uintptr_t)address {
    if ((self = [super init])) {
        _frameAddress = @(address);
        _needsSymbolication = YES;
        RSC_Mach_Header_Info *header = rsc_mach_headers_image_at_address(address);
        if (header) {
            _machoFile = header->name ? @(header->name) : nil;
            _machoLoadAddress = @((uintptr_t)header->header);
            _machoVmAddress = @(header->imageVmAddr);
            _machoUuid = header->uuid ? [[NSUUID alloc] initWithUUIDBytes:header->uuid].UUIDString : nil;
        }
    }
    return self;
}

- (void)symbolicateIfNeeded {
    if (!self.needsSymbolication) {
        return;
    }
    self.needsSymbolication = NO;
    
    uintptr_t frameAddress = self.frameAddress.unsignedIntegerValue;
    uintptr_t instructionAddress = self.isPc ? frameAddress: CALL_INSTRUCTION_FROM_RETURN_ADDRESS(frameAddress);
    struct rsc_symbolicate_result result;
    rsc_symbolicate(instructionAddress, &result);
    
    if (result.function_address) {
        self.symbolAddress = @(result.function_address);
    }
    if (result.function_name) {
        self.method = @(result.function_name);
    }
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[RSCKeyMachoFile] = self.machoFile;
    dict[RSCKeyMethod] = self.method;
    dict[RSCKeyMachoUUID] = self.machoUuid;
    dict[RSCKeyFrameAddress] = FormatMemoryAddress(self.frameAddress);
    dict[RSCKeySymbolAddr] = FormatMemoryAddress(self.symbolAddress);
    dict[RSCKeyMachoLoadAddr] = FormatMemoryAddress(self.machoLoadAddress);
    dict[RSCKeyMachoVMAddress] = FormatMemoryAddress(self.machoVmAddress);
    dict[RSCKeyIsPC] = self.isPc ? @YES : nil;
    dict[RSCKeyIsLR] = self.isLr ? @YES : nil;
    dict[RSCKeyType] = self.type;
    dict[@"codeIdentifier"] = self.codeIdentifier;
    dict[@"columnNumber"] = self.columnNumber;
    dict[@"file"] = self.file;
    dict[@"inProject"] = self.inProject;
    dict[@"lineNumber"] = self.lineNumber;
    return dict;
}

@end
