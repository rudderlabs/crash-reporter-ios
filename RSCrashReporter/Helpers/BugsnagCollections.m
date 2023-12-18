//
//  Copyright (c) 2016 RSCrashReporter, Inc. All rights reserved.
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

#import "RSCrashReporterCollections.h"

#import "RSC_RFC3339DateTool.h"
#import "RSCJSONSerialization.h"

// MARK: NSArray

NSArray * RSCArrayWithObject(id _Nullable object) {
    return object ? @[(id _Nonnull)object] : @[];
}

void RSCArrayAddIfNonnull(NSMutableArray *array, id _Nullable object) {
    if (object) {
        [array addObject:(id _Nonnull)object];
    }
}

NSArray * RSCArrayMap(NSArray *array, id _Nullable (^ transform)(id)) {
    NSMutableArray *mappedArray = [NSMutableArray array];
    for (id object in array) {
        id mapped = transform(object);
        if (mapped) {
            [mappedArray addObject:mapped];
        }
    }
    return mappedArray;
}

NSArray * RSCArraySubarrayFromIndex(NSArray *array, NSUInteger index) {
    if (index >= array.count) {
        return @[];
    }
    return [array subarrayWithRange:NSMakeRange(index, array.count - index)];
}

// MARK: - NSDictionary

NSDictionary * RSCDictionaryWithKeyAndObject(NSString *key, id _Nullable object) {
    return object ? @{key: (id _Nonnull)object} : @{};
}

NSDictionary *RSCDictMerge(NSDictionary *source, NSDictionary *destination) {
    if ([destination count] == 0) {
        return source;
    }
    if ([source count] == 0) {
        return destination;
    }
    
    NSMutableDictionary *dict = [destination mutableCopy];
    for (id key in [source allKeys]) {
        id srcEntry = source[key];
        id dstEntry = destination[key];
        if ([dstEntry isKindOfClass:[NSDictionary class]] &&
            [srcEntry isKindOfClass:[NSDictionary class]]) {
            srcEntry = RSCDictMerge(srcEntry, dstEntry);
        }
        dict[key] = srcEntry;
    }
    return dict;
}

NSDictionary * RSCJSONDictionary(NSDictionary *dictionary) {
    if (!dictionary) {
        return nil;
    }
    if (RSCJSONDictionaryIsValid(dictionary, nil)) {
        return dictionary;
    }
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    for (id key in dictionary) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        const id value = dictionary[key];
        if (RSCJSONDictionaryIsValid(@{key: value}, nil)) {
            json[key] = value;
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            json[key] = RSCJSONDictionary(value);
        } else {
            json[key] = ((NSObject *)value).description;
        }
    }
    return json;
}

// MARK: - NSSet

void RSCSetAddIfNonnull(NSMutableSet *set, id _Nullable object) {
    if (object) {
        [set addObject:(id _Nonnull)object];
    }
}

// MARK: - Deserialization

NSDictionary * _Nullable RSCDeserializeDict(id _Nullable rawValue) {
    if (![rawValue isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return (NSDictionary *)rawValue;
}

id _Nullable RSCDeserializeObject(id _Nullable rawValue, id _Nullable (^ deserializer)(NSDictionary * _Nonnull dict)) {
    if (![rawValue isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return deserializer((NSDictionary *)rawValue);
}

id _Nullable RSCDeserializeArrayOfObjects(id _Nullable rawValue, id _Nullable (^ deserializer)(NSDictionary * _Nonnull dict)) {
    if (![rawValue isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return RSCArrayMap((NSArray *)rawValue, ^id _Nullable(id _Nonnull value) {
        return RSCDeserializeObject(value, deserializer);
    });
}

NSString * _Nullable RSCDeserializeString(id _Nullable rawValue) {
    if (![rawValue isKindOfClass:[NSString class]]) {
        return nil;
    }
    return (NSString *)rawValue;
}

NSDate * _Nullable RSCDeserializeDate(id _Nullable rawValue) {
    if (![rawValue isKindOfClass:[NSString class]]) {
        return nil;
    }
    return [RSC_RFC3339DateTool dateFromString:(NSString *)rawValue];
}

NSNumber * _Nullable RSCDeserializeNumber(id  _Nullable rawValue) {
    if (![rawValue isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    return (NSNumber *)rawValue;
}
