#import <Foundation/Foundation.h>

enum {
    GJMaximumMessageCount = 500,
    GJMessageTextLimit = 2000,
    GJChatTextBudget = 60000,
    GJMemoryFieldLimit = 4000
};

@interface GJMessage : NSObject
@property(nonatomic, copy) NSString *sender;
@property(nonatomic, copy) NSString *receiver;
@property(nonatomic, copy) NSString *text;
@property(nonatomic) NSTimeInterval timestamp;
@property(nonatomic) NSInteger type;
@property(nonatomic) BOOL isFromMe;
@end

@interface GJChatContext : NSObject
@property(nonatomic, copy) NSString *accountID;
@property(nonatomic, copy) NSString *contactID;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *identityNote; // Local UI only; never included in the AI payload.
@property(nonatomic) BOOL isGroup;
@property(nonatomic, copy) NSString *sourceNote;
@property(nonatomic, copy) NSArray<GJMessage *> *messages;
@end

FOUNDATION_EXPORT NSString *GJClip(NSString *text, NSUInteger limit);
FOUNDATION_EXPORT NSError *GJError(NSString *message);
