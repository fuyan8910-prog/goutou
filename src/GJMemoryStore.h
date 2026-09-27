#import <Foundation/Foundation.h>
@class GJChatContext;
@interface GJMemoryStore : NSObject
+ (instancetype)shared;
@property(nonatomic, readonly) NSUInteger generation;
- (NSDictionary *)memoryForContext:(GJChatContext *)context error:(NSError **)error;
- (BOOL)saveMemory:(NSDictionary *)memory context:(GJChatContext *)context error:(NSError **)error;
- (BOOL)clearContext:(GJChatContext *)context error:(NSError **)error;
- (BOOL)clearAll:(NSError **)error;
- (void)invalidatePendingWrites;
@end
