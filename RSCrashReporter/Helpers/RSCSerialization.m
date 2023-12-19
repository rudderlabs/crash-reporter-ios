#import "RSCSerialization.h"

#import "RSCJSONSerialization.h"
#import "RSCrashReporterLogger.h"

static NSArray * RSCSanitizeArray(NSArray *input);

id RSCSanitizeObject(id obj) {
    if ([obj isKindOfClass:[NSArray class]]) {
        return RSCSanitizeArray(obj);
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        return RSCSanitizeDict(obj);
    } else if ([obj isKindOfClass:[NSString class]]) {
        return obj;
    } else if ([obj isKindOfClass:[NSNumber class]]
               && ![obj isEqualToNumber:[NSDecimalNumber notANumber]]
               && !isinf([obj doubleValue])) {
        return obj;
    }
    return nil;
}

NSMutableDictionary * RSCSanitizePossibleDict(NSDictionary *input) {
    if (![input isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return RSCSanitizeDict(input);
}

NSMutableDictionary * RSCSanitizeDict(NSDictionary *input) {
    __block NSMutableDictionary *output =
        [NSMutableDictionary dictionaryWithCapacity:[input count]];
    [input enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj,
                                               __unused BOOL *_Nonnull stop) {
      if ([key isKindOfClass:[NSString class]]) {
          id cleanedObject = RSCSanitizeObject(obj);
          if (cleanedObject)
              output[key] = cleanedObject;
      }
    }];
    return output;
}

static NSArray * RSCSanitizeArray(NSArray *input) {
    NSMutableArray *output = [NSMutableArray arrayWithCapacity:[input count]];
    for (id obj in input) {
        id cleanedObject = RSCSanitizeObject(obj);
        if (cleanedObject)
            [output addObject:cleanedObject];
    }
    return output;
}

NSString * RSCTruncatePossibleString(RSCTruncateContext *context, NSString *string) {
    if (![string isKindOfClass:[NSString class]]) {
        return nil;
    }
    return RSCTruncateString(context, string);
}

NSString * RSCTruncateString(RSCTruncateContext *context, NSString *string) {
    const NSUInteger inputLength = string.length;
    if (inputLength <= context->maxLength) return string;
    // Prevent chopping in the middle of a composed character sequence
    NSRange range = [string rangeOfComposedCharacterSequenceAtIndex:context->maxLength];
    NSString *output = [string substringToIndex:range.location];
    NSUInteger count = inputLength - range.location;
    context->strings++;
    context->length += count;
    return [output stringByAppendingFormat:@"\n***%lu CHARS TRUNCATED***", (unsigned long)count];
}

id RSCTruncateStrings(RSCTruncateContext *context, id object) {
    if ([object isKindOfClass:[NSString class]]) {
        return RSCTruncateString(context, object);
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *output = [NSMutableDictionary dictionaryWithCapacity:((NSDictionary *)object).count];
        for (NSString *key in (NSDictionary *)object) {
            id value = ((NSDictionary *)object)[key];
            output[key] = RSCTruncateStrings(context, value);
        }
        return output;
    }
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *output = [NSMutableArray arrayWithCapacity:((NSArray *)object).count];
        for (id element in (NSArray *)object) {
            [output addObject:RSCTruncateStrings(context, element)];
        }
        return output;
    }
    return object;
}
