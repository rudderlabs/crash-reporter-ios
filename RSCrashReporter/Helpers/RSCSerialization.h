#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Removes any values which would be rejected by NSJSONSerialization for
 documented reasons or is NSNull

 @param input a dictionary
 @return a new dictionary
 */
NSMutableDictionary *RSCSanitizeDict(NSDictionary * input);

NSMutableDictionary *_Nullable RSCSanitizePossibleDict(NSDictionary *_Nullable input);

/**
 Cleans the object, including nested dictionary and array values

 @param obj any object or nil
 @return a new object for serialization or nil if the obj was incompatible or NSNull
 */
id _Nullable RSCSanitizeObject(id _Nullable obj);

typedef struct _RSCTruncateContext {
    NSUInteger maxLength;
    NSUInteger strings;
    NSUInteger length;
} RSCTruncateContext;

NSString * RSCTruncateString(RSCTruncateContext *context, NSString * string);
NSString *_Nullable RSCTruncatePossibleString(RSCTruncateContext *context, NSString *_Nullable string);

id RSCTruncateStrings(RSCTruncateContext *context, id object);

NS_ASSUME_NONNULL_END
