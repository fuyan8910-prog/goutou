#import "GJMemoryStore.h"
#import "GJModels.h"
#import <CommonCrypto/CommonDigest.h>
@interface GJMemoryStore ()
@property(nonatomic) NSUInteger generation;
@end
@implementation GJMemoryStore
+ (instancetype)shared { static GJMemoryStore *s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [self new]; }); return s; }
- (NSURL *)directory {
    NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [base URLByAppendingPathComponent:@"GoutouJunshi/Memory" isDirectory:YES];
}
- (NSURL *)fileForContext:(GJChatContext *)context {
    if (!context.accountID.length || !context.contactID.length) return nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[context.accountID, context.contactID] options:0 error:NULL];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *name = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [name appendFormat:@"%02x", digest[i]];
    return [[self directory] URLByAppendingPathComponent:[name stringByAppendingString:@".json"]];
}
- (NSDictionary *)memoryForContext:(GJChatContext *)context error:(NSError **)error {
    NSURL *file = [self fileForContext:context];
    if (!file) { if (error) *error = GJError(@"无法确认当前微信账号，长期记忆不可用。"); return nil; }
    if (![NSFileManager.defaultManager fileExistsAtPath:file.path]) return @{};
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file.path error:error];
    if (!attributes) return nil;
    if ([attributes[NSFileSize] unsignedLongLongValue] > 262144) { if (error) *error = GJError(@"记忆文件过大，请清除后重试。"); return nil; }
    NSData *data = [NSData dataWithContentsOfURL:file options:0 error:error];
    if (!data) return nil;
    if (data.length > 262144) { if (error) *error = GJError(@"记忆文件异常，请清除后重试。"); return nil; }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![object isKindOfClass:NSDictionary.class]) { if (error) *error = GJError(@"记忆格式异常。"); return nil; }
    NSMutableDictionary *clean = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"relationship", @"people", @"events", @"explicit", @"summary", @"voice"]) {
        clean[key] = GJClip(object[key], GJMemoryFieldLimit);
    }
    return clean;
}
- (BOOL)saveMemory:(NSDictionary *)memory context:(GJChatContext *)context error:(NSError **)error {
    NSURL *file = [self fileForContext:context];
    if (!file) { if (error) *error = GJError(@"账号或联系人缺失，无法保存记忆。"); return NO; }
    NSURL *dir = [self directory];
    if (![NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES
                                               attributes:@{NSFileProtectionKey:NSFileProtectionComplete} error:error]) return NO;
    if (![dir setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:error]) return NO;
    NSMutableDictionary *clean = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"relationship", @"people", @"events", @"explicit", @"summary", @"voice"]) clean[key] = GJClip(memory[key], GJMemoryFieldLimit);
    NSData *data = [NSJSONSerialization dataWithJSONObject:clean options:0 error:error];
    BOOL saved = data && [data writeToURL:file options:NSDataWritingAtomic | NSDataWritingFileProtectionComplete error:error];
    if (saved) [self invalidatePendingWrites];
    return saved;
}
- (void)invalidatePendingWrites { self.generation++; }
- (BOOL)clearContext:(GJChatContext *)context error:(NSError **)error {
    [self invalidatePendingWrites];
    NSURL *file = [self fileForContext:context];
    if (!file) { if (error) *error = GJError(@"无法确认账号或联系人。"); return NO; }
    return ![NSFileManager.defaultManager fileExistsAtPath:file.path] || [NSFileManager.defaultManager removeItemAtURL:file error:error];
}
- (BOOL)clearAll:(NSError **)error {
    [self invalidatePendingWrites];
    NSURL *dir = [self directory];
    if (!dir) { if (error) *error = GJError(@"无法定位本地记忆目录。"); return NO; }
    return ![NSFileManager.defaultManager fileExistsAtPath:dir.path] || [NSFileManager.defaultManager removeItemAtURL:dir error:error];
}
@end
