//
//  RSC_KSCrashReportFields.h
//
//  Created by Karl Stenerud on 2012-10-07.
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

#ifndef HDR_RSC_KSCrashReportFields_h
#define HDR_RSC_KSCrashReportFields_h

#pragma mark - Report Types -

#define RSC_KSCrashReportType_Minimal "minimal"
#define RSC_KSCrashReportType_Standard "standard"
#define RSC_KSCrashReportType_Custom "custom"

#pragma mark - Exception Types -

#define RSC_KSCrashExcType_CPPException "cpp_exception"
#define RSC_KSCrashExcType_Mach "mach"
#define RSC_KSCrashExcType_NSException "nsexception"
#define RSC_KSCrashExcType_Signal "signal"
#define RSC_KSCrashExcType_User "user"

#pragma mark - Common -

#define RSC_KSCrashField_Address "address"
#define RSC_KSCrashField_Contents "contents"
#define RSC_KSCrashField_Exception "exception"
#define RSC_KSCrashField_FirstObject "first_object"
#define RSC_KSCrashField_Index "index"
#define RSC_KSCrashField_Ivars "ivars"
#define RSC_KSCrashField_Language "language"
#define RSC_KSCrashField_Name "name"
#define RSC_KSCrashField_Type "type"
#define RSC_KSCrashField_UserInfo "userInfo"
#define RSC_KSCrashField_UUID "uuid"

#define RSC_KSCrashField_Error "error"
#define RSC_KSCrashField_JSONData "json_data"

#pragma mark - Notable Address -

#define RSC_KSCrashField_Class "class"
#define RSC_KSCrashField_LastDeallocObject "last_deallocated_obj"

#pragma mark - Backtrace -

#define RSC_KSCrashField_InstructionAddr "instruction_addr"
#define RSC_KSCrashField_LineOfCode "line_of_code"
#define RSC_KSCrashField_ObjectAddr "object_addr"
#define RSC_KSCrashField_ObjectName "object_name"
#define RSC_KSCrashField_SymbolAddr "symbol_addr"
#define RSC_KSCrashField_SymbolName "symbol_name"

#pragma mark - Stack Dump -

#define RSC_KSCrashField_DumpEnd "dump_end"
#define RSC_KSCrashField_DumpStart "dump_start"
#define RSC_KSCrashField_GrowDirection "grow_direction"
#define RSC_KSCrashField_Overflow "overflow"
#define RSC_KSCrashField_StackPtr "stack_pointer"

#pragma mark - Thread Dump -

#define RSC_KSCrashField_Backtrace "backtrace"
#define RSC_KSCrashField_Basic "basic"
#define RSC_KSCrashField_Crashed "crashed"
#define RSC_KSCrashField_CrashInfoMessage "crash_info_message"
#define RSC_KSCrashField_CurrentThread "current_thread"
#define RSC_KSCrashField_DispatchQueue "dispatch_queue"
#define RSC_KSCrashField_Registers "registers"
#define RSC_KSCrashField_Skipped "skipped"
#define RSC_KSCrashField_Stack "stack"

#pragma mark - Binary Image -

#define RSC_KSCrashField_CPUSubType "cpu_subtype"
#define RSC_KSCrashField_CPUType "cpu_type"
#define RSC_KSCrashField_ImageAddress "image_addr"
#define RSC_KSCrashField_ImageVmAddress "image_vmaddr"
#define RSC_KSCrashField_ImageSize "image_size"

#pragma mark - Memory -

#define RSC_KSCrashField_Free "free"
#define RSC_KSCrashField_Size "size"

#pragma mark - Error -

#define RSC_KSCrashField_Backtrace "backtrace"
#define RSC_KSCrashField_Code "code"
#define RSC_KSCrashField_CodeName "code_name"
#define RSC_KSCrashField_CPPException "cpp_exception"
#define RSC_KSCrashField_ExceptionName "exception_name"
#define RSC_KSCrashField_Mach "mach"
#define RSC_KSCrashField_NSException "nsexception"
#define RSC_KSCrashField_Reason "reason"
#define RSC_KSCrashField_Signal "signal"
#define RSC_KSCrashField_Subcode "subcode"
#define RSC_KSCrashField_UserReported "user_reported"
#define RSC_KSCrashField_Overrides "overrides"
#define RSC_KSCrashField_EventJson "event"
#define RSC_KSCrashField_HandledState "handledState"
#define RSC_KSCrashField_Metadata "metaData"
#define RSC_KSCrashField_State "state"
#define RSC_KSCrashField_Config "config"
#define RSC_KSCrashField_DiscardDepth "depth"

#pragma mark - Process State -

#define RSC_KSCrashField_LastDeallocedNSException "last_dealloced_nsexception"
#define RSC_KSCrashField_ProcessState "process"

#pragma mark - App Stats -

#define RSC_KSCrashField_ActiveTimeSinceLaunch "active_time_since_launch"
#define RSC_KSCrashField_AppInFG "application_in_foreground"
#define RSC_KSCrashField_BGTimeSinceLaunch "background_time_since_launch"

#pragma mark - Report -

#define RSC_KSCrashField_Crash "crash"
#define RSC_KSCrashField_ID "id"
#define RSC_KSCrashField_ProcessName "process_name"
#define RSC_KSCrashField_Report "report"
#define RSC_KSCrashField_Timestamp "timestamp"
#define RSC_KSCrashField_Timestamp_Millis "timestamp_millis"
#define RSC_KSCrashField_Version "version"

#pragma mark Minimal
#define RSC_KSCrashField_CrashedThread "crashed_thread"

#pragma mark Standard
#define RSC_KSCrashField_AppStats "application_stats"
#define RSC_KSCrashField_BinaryImages "binary_images"
#define RSC_KSCrashField_Disk "disk"
#define RSC_KSCrashField_SystemAtCrash "system_atcrash"
#define RSC_KSCrashField_System "system"
#define RSC_KSCrashField_Memory "memory"
#define RSC_KSCrashField_Threads "threads"
#define RSC_KSCrashField_User "user"
#define RSC_KSCrashField_UserAtCrash "user_atcrash"
#define RSC_KSCrashField_OnCrashMetadataSectionName "onCrash"

#pragma mark Incomplete
#define RSC_KSCrashField_Incomplete "incomplete"
#define RSC_KSCrashField_RecrashReport "recrash_report"

#endif
