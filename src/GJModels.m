#import "GJModels.h"
@implementation GJMessage
@end
@implementation GJChatContext
@end
NSString *GJClip(NSString *text, NSUInteger limit) {
    if (![text isKindOfClass:NSString.class]) return @"";
    if (text.length <= limit) return text;
    if (!limit) return @"";
    NSRange last = [text rangeOfComposedCharacterSequenceAtIndex:limit - 1];
    NSUInteger end = NSMaxRange(last) > limit ? last.location : limit;
    return [text substringToIndex:end];
}
NSError *GJError(NSString *message) {
    return [NSError errorWithDomain:@"com.fuyan.goutoujunshi" code:1
                          userInfo:@{NSLocalizedDescriptionKey:message ?: @"操作失败"}];
}
