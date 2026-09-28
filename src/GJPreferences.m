#import "GJPreferences.h"
#import "GJModels.h"
#import <Security/Security.h>
@implementation GJPreferences
+ (NSUserDefaults *)defaults {
    static NSUserDefaults *value; static dispatch_once_t once;
    dispatch_once(&once, ^{
        value = [[NSUserDefaults alloc] initWithSuiteName:@"com.fuyan.goutoujunshi"];
        [value registerDefaults:@{@"messageCount":@20, @"memoryEnabled":@NO, @"model":@"deepseek-chat"}];
    });
    return value;
}
+ (NSInteger)messageCount { return MAX(5, MIN(GJMaximumMessageCount, [[self defaults] integerForKey:@"messageCount"])); }
+ (BOOL)memoryEnabled { return [[self defaults] boolForKey:@"memoryEnabled"]; }
+ (NSString *)model { return [[self defaults] stringForKey:@"model"] ?: @"deepseek-chat"; }
+ (NSMutableDictionary *)keyQuery {
    return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService:@"com.fuyan.goutoujunshi.deepseek",
              (__bridge id)kSecAttrAccount:@"api-key"} mutableCopy];
}
+ (NSString *)APIKey:(NSError **)error {
    NSMutableDictionary *query = [self keyQuery];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) return @"";
    if (status != errSecSuccess) {
        if (error) *error = GJError([NSString stringWithFormat:@"无法读取钥匙串（%d），请解锁设备后重试。", (int)status]);
        return nil;
    }
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}
+ (BOOL)saveAPIKey:(NSString *)key error:(NSError **)error {
    NSMutableDictionary *query = [self keyQuery];
    OSStatus status;
    if (!key.length) {
        status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecItemNotFound) status = errSecSuccess;
    } else {
        NSDictionary *attributes = @{(__bridge id)kSecValueData:[key dataUsingEncoding:NSUTF8StringEncoding],
                                    (__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
        status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
        if (status == errSecItemNotFound) {
            [query addEntriesFromDictionary:attributes];
            status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        }
    }
    if (status != errSecSuccess && error) *error = GJError([NSString stringWithFormat:@"钥匙串保存失败（%d），未回退为明文存储。", (int)status]);
    return status == errSecSuccess;
}
@end
