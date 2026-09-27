#import <Foundation/Foundation.h>
@class GJChatContext;
@interface GJPromptBuilder : NSObject
+ (NSArray<NSDictionary *> *)messagesForContext:(GJChatContext *)context memory:(NSDictionary *)memory;
+ (NSDictionary *)validatedAnalysis:(id)object error:(NSError **)error;
@end
