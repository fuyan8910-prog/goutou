#import <UIKit/UIKit.h>
#import "GJModels.h"
@interface GJWeChatAdapter : NSObject
+ (UIViewController *)visibleControllerInWindow:(UIWindow *)window;
- (NSString *)diagnosticsForController:(UIViewController *)controller;
- (GJChatContext *)contextFromController:(UIViewController *)controller limit:(NSUInteger)limit error:(NSError **)error;
@end
