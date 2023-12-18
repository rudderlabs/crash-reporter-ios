//
//  RSCrashReporterUser.m
//  RSCrashReporter
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "RSCrashReporterUser+Private.h"

#import "RSC_KSSystemInfo.h"

RSC_OBJC_DIRECT_MEMBERS
@implementation RSCrashReporterUser

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _id = dict[@"id"];
        _email = dict[@"email"];
        _name = dict[@"name"];
    }
    return self;
}

- (instancetype)initWithId:(NSString *)id name:(NSString *)name emailAddress:(NSString *)emailAddress {
    if ((self = [super init])) {
        _id = id;
        _name = name;
        _email = emailAddress;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"id"] = self.id;
    dict[@"email"] = self.email;
    dict[@"name"] = self.name;
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (RSCrashReporterUser *)withId {
    if (self.id) {
        return self;
    } else {
        return [[RSCrashReporterUser alloc] initWithId:[RSC_KSSystemInfo deviceAndAppHash]
                                          name:self.name
                                  emailAddress:self.email];
    }
}

@end

// MARK: - User Persistence

static NSString * const RSCrashReporterUserEmailAddressKey = @"RSCrashReporterUserEmailAddress";
static NSString * const RSCrashReporterUserIdKey           = @"RSCrashReporterUserUserId";
static NSString * const RSCrashReporterUserNameKey         = @"RSCrashReporterUserName";

RSCrashReporterUser * RSCGetPersistedUser(void) {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [[RSCrashReporterUser alloc] initWithId:[userDefaults stringForKey:RSCrashReporterUserIdKey]
                                      name:[userDefaults stringForKey:RSCrashReporterUserNameKey]
                              emailAddress:[userDefaults stringForKey:RSCrashReporterUserEmailAddressKey]];
}

void RSCSetPersistedUser(RSCrashReporterUser *user) {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:user.email forKey:RSCrashReporterUserEmailAddressKey];
    [userDefaults setObject:user.id forKey:RSCrashReporterUserIdKey];
    [userDefaults setObject:user.name forKey:RSCrashReporterUserNameKey];
}
