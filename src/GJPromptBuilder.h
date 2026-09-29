#import <Foundation/Foundation.h>
@class GJChatContext;
@interface GJPromptBuilder : NSObject
+ (NSArray<NSDictionary *> *)messagesForContext:(GJChatContext *)context memory:(NSDictionary *)memory mode:(NSInteger)mode focus:(NSString *)focus;
+ (NSDictionary *)validatedAnalysis:(id)object updatesMemory:(BOOL)updatesMemory error:(NSError **)error;
@end
