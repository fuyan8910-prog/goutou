#import <Foundation/Foundation.h>
@interface GJDeepSeekClient : NSObject
- (void)analyzeMessages:(NSArray<NSDictionary *> *)messages APIKey:(NSString *)key model:(NSString *)model
            completion:(void (^)(NSDictionary *result, NSError *error))completion;
- (void)cancel;
@end
