//
//  URLSessionMock.h
//  RSCrashReporter
//
//  Created by Nick Dowell on 19/11/2020.
//  Copyright © 2020 RSCrashReporter Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface URLSessionMock : NSObject

- (void)mockData:(nullable NSData *)data response:(nullable NSURLResponse *)response error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
