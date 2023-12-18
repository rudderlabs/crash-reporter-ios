//
//  RSCJSONSerialization.m
//  RSCrashReporter
//
//  Created by Karl Stenerud on 03.09.20.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import "RSCJSONSerialization.h"

static NSError* wrapException(NSException* exception) {
    return [NSError errorWithDomain:@"RSCJSONSerializationErrorDomain" code:1 userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]
    }];
}

BOOL RSCJSONDictionaryIsValid(NSDictionary *obj, NSError **error) {
    @try {
        if (![obj isKindOfClass:[NSDictionary class]] ||
            ![NSJSONSerialization isValidJSONObject:(id _Nonnull)obj]) {
            if (error) {
                *error = [NSError errorWithDomain:@"RSCJSONSerializationErrorDomain" code:0 userInfo:@{
                    NSLocalizedDescriptionKey: @"Not a valid JSON object"}];
            }
            return NO;
        }
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = wrapException(exception);
        }
        return NO;
    }
}

NSData *_Nullable RSCJSONDataFromDictionary(NSDictionary *obj, NSError **error) {
    if (!RSCJSONDictionaryIsValid(obj, error)) {
        return nil;
    }
    @try {
        return [NSJSONSerialization dataWithJSONObject:(id _Nonnull)obj options:0 error:error];
    } @catch (NSException *exception) {
        if (error) {
            *error = wrapException(exception);
        }
        return nil;
    }
    return nil;
}

NSDictionary *_Nullable RSCJSONDictionaryFromData(NSData *data, NSJSONReadingOptions opt, NSError **error) {
    @try {
        id obj = [NSJSONSerialization JSONObjectWithData:data options:opt error:error];
        return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
    } @catch (NSException *exception) {
        if (error) {
            *error = wrapException(exception);
        }
        return nil;
    }
    return nil;
}

BOOL RSCJSONWriteToFileAtomically(NSDictionary *JSONObject, NSString *file, NSError **errorPtr) {
    NSData *data = RSCJSONDataFromDictionary(JSONObject, errorPtr);
    return [data writeToFile:file options:NSDataWritingAtomic error:errorPtr];
}

NSDictionary *_Nullable RSCJSONDictionaryFromFile(NSString *file, NSJSONReadingOptions options, NSError **errorPtr) {
    NSData *data = [NSData dataWithContentsOfFile:file options:0 error:errorPtr];
    if (!data) {
        return nil;
    }
    return RSCJSONDictionaryFromData(data, options, errorPtr);
}
