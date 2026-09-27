#import <Foundation/Foundation.h>
@interface GJPreferences : NSObject
+ (NSUserDefaults *)defaults;
+ (NSInteger)messageCount;
+ (BOOL)memoryEnabled;
+ (NSString *)model;
+ (NSString *)APIKey:(NSError **)error;
+ (BOOL)saveAPIKey:(NSString *)key error:(NSError **)error;
@end
