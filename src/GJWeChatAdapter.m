#import "GJWeChatAdapter.h"
#import <objc/runtime.h>
#include <string.h>
#include <stdlib.h>

// All private access lives here. Validate ABI before invoking; never guess a multi-argument ABI.
static const char *GJType(const char *type) {
    if (!type) return "";
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}
static id GJCall(id target, NSString *name, id argument, BOOL hasArgument) {
    if (!target) return nil;
    @try {
        SEL selector = NSSelectorFromString(name);
        if (![target respondsToSelector:selector]) return nil;
        NSMethodSignature *sig = [target methodSignatureForSelector:selector];
        if (!sig || sig.numberOfArguments != (hasArgument ? 3u : 2u) || *GJType(sig.methodReturnType) != '@' || sig.methodReturnLength != sizeof(id)) return nil;
        if (hasArgument && !strchr("@#", *GJType([sig getArgumentTypeAtIndex:2]))) return nil;
        NSInvocation *call = [NSInvocation invocationWithMethodSignature:sig];
        call.target = target; call.selector = selector;
        if (hasArgument) { __unsafe_unretained id arg = argument; [call setArgument:&arg atIndex:2]; }
        [call invoke];
        __unsafe_unretained id result = nil;
        [call getReturnValue:&result];
        return result;
    } @catch (__unused NSException *exception) { return nil; }
}
static id GJField(id object, NSString *name) {
    if (!object) return nil;
    id result = GJCall(object, name, nil, NO);
    if (result) return result;
    @try {
        Ivar ivar = class_getInstanceVariable([object class], name.UTF8String);
        if (!ivar) ivar = class_getInstanceVariable([object class], [@"_" stringByAppendingString:name].UTF8String);
        if (ivar && *GJType(ivar_getTypeEncoding(ivar)) == '@') return object_getIvar(object, ivar);
    } @catch (__unused NSException *exception) {}
    return nil;
}
static NSString *GJString(id value) { return [value isKindOfClass:NSString.class] ? value : nil; }
static NSNumber *GJNumber(id object, NSString *name) {
    // KVC is limited to known numeric message fields, with exception and result checks.
    @try {
        id value = [object valueForKey:name];
        return [value isKindOfClass:NSNumber.class] ? value : nil;
    } @catch (__unused NSException *exception) { return nil; }
}
static id GJContactManager(void) {
    Class centerClass = NSClassFromString(@"MMServiceCenter");
    Class contactClass = NSClassFromString(@"CContactMgr");
    if (!centerClass || !contactClass) return nil;
    id center = GJCall(centerClass, @"defaultCenter", nil, NO);
    return GJCall(center, @"getService:", contactClass, YES);
}
static NSArray<NSString *> *GJMessageFields(id object) {
    NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSetWithArray:@[@"m_arrMsg", @"m_arrMessages", @"m_messageList"]];
    Class cls = [object class];
    for (NSUInteger depth = 0; cls && depth < 6 && names.count < 16; depth++, cls = class_getSuperclass(cls)) {
        unsigned int count = 0; Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int i = 0; i < count && names.count < 16; i++) {
            const char *raw = ivar_getName(ivars[i]);
            if (!raw || *GJType(ivar_getTypeEncoding(ivars[i])) != '@') continue;
            NSString *name = [NSString stringWithUTF8String:raw];
            NSString *lower = name.lowercaseString;
            if ([lower containsString:@"msg"] || [lower containsString:@"message"]) [names addObject:name];
        }
        free(ivars);
    }
    return names.array;
}
@implementation GJWeChatAdapter
- (NSString *)diagnosticsForController:(UIViewController *)controller {
    NSMutableString *text = [NSMutableString stringWithString:@"仅结构信息，不含账号、联系人、消息正文或 Key。不会上传。\n"];
    @try {
        for (NSUInteger depth = 0; controller && depth < 6; depth++, controller = controller.parentViewController) {
            [text appendFormat:@"\n控制器：%@\n候选消息字段：%@\n", NSStringFromClass(controller.class), [GJMessageFields(controller) componentsJoinedByString:@", "]];
        }
        [text appendFormat:@"\nMMServiceCenter：%@\nCContactMgr：%@", NSClassFromString(@"MMServiceCenter") ? @"存在" : @"缺失", NSClassFromString(@"CContactMgr") ? @"存在" : @"缺失"];
    } @catch (__unused NSException *exception) { [text appendString:@"\n结构检查失败。"]; }
    return text;
}
+ (UIViewController *)visibleControllerInWindow:(UIWindow *)window {
    UIViewController *vc = window.rootViewController;
    for (NSUInteger i = 0; i < 24 && vc; i++) {
        UIViewController *next = nil;
        if (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) next = vc.presentedViewController;
        else if ([vc isKindOfClass:UINavigationController.class]) next = ((UINavigationController *)vc).visibleViewController;
        else if ([vc isKindOfClass:UITabBarController.class]) next = ((UITabBarController *)vc).selectedViewController;
        else {
            for (UIViewController *child in vc.children.reverseObjectEnumerator) {
                if (child.isViewLoaded && child.view.window == window && !child.view.hidden) { next = child; break; }
            }
        }
        if (!next || next == vc) break;
        vc = next;
    }
    return vc;
}
- (GJChatContext *)contextFromController:(UIViewController *)controller limit:(NSUInteger)limit error:(NSError **)error {
    if (!NSThread.isMainThread) { if (error) *error = GJError(@"请在主线程读取当前会话。"); return nil; }
    @try {
        id chat = nil; NSString *username = nil;
        UIViewController *candidate = controller;
        for (NSUInteger i = 0; i < 6 && candidate; i++, candidate = candidate.parentViewController) {
            username = GJString(GJCall(candidate, @"getChatUsername", nil, NO));
            if (!username.length) username = GJString(GJField(GJField(candidate, @"m_contact"), @"m_nsUsrName"));
            if (username.length) { chat = candidate; break; }
        }
        if (!chat || !username.length) { if (error) *error = GJError(@"未识别当前聊天。请进入具体聊天页面后再打开狗头军师；此版本控制器也可能尚未适配。"); return nil; }
        id contactMgr = GJContactManager();
        NSString *selfID = GJString(GJField(GJCall(contactMgr, @"getSelfContact", nil, NO), @"m_nsUsrName"));
        if (!selfID.length) { if (error) *error = GJError(@"未能确认当前微信账号，已停止读取以避免联系人记忆串号。"); return nil; }
        id contact = GJCall(contactMgr, @"getContact:", username, YES);
        NSString *display = GJString(GJField(contact, @"m_nsRemark"));
        if (!display.length) display = GJString(GJField(contact, @"m_nsNickName"));
        GJChatContext *context = [GJChatContext new];
        context.accountID = selfID; context.contactID = username; context.displayName = display.length ? display : username;
        context.messages = @[];
        context.sourceNote = @"仅当前页面已加载且校验属于该会话的消息，不保证是数据库中最新或完整记录。单条最多约 1000 字，总计最多约 12000 字。";
        NSMutableArray<GJMessage *> *messages = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        // Only inspect a bounded tail of the active controller's loaded message list.
        // These are candidates, not a claim of verified 8.0.75 private interfaces.
        for (NSString *key in GJMessageFields(chat)) {
            id value = GJField(chat, key);
            if (![value isKindOfClass:NSArray.class]) continue;
            NSArray *array = value;
            NSUInteger start = array.count > 200 ? array.count - 200 : 0;
            for (NSUInteger index = start; index < array.count; index++) {
                id wrap = array[index];
                id inner = GJField(wrap, @"m_msgWrap");
                if (inner) wrap = inner;
                NSString *from = GJString(GJField(wrap, @"m_nsFromUsr"));
                NSString *to = GJString(GJField(wrap, @"m_nsToUsr"));
                if (!from.length || !to.length) continue;
                BOOL outgoing = [from isEqualToString:selfID] && [to isEqualToString:username];
                BOOL incoming = [from isEqualToString:username] && [to isEqualToString:selfID];
                if (!outgoing && !incoming) continue;
                // Pointer identity removes duplicate wraps without collapsing repeated genuine messages.
                NSValue *identity = [NSValue valueWithNonretainedObject:wrap];
                if ([seen containsObject:identity]) continue;
                NSNumber *type = GJNumber(wrap, @"m_uiMessageType");
                NSNumber *time = GJNumber(wrap, @"m_uiCreateTime");
                if (!type || !time || time.doubleValue <= 0) continue;
                NSString *body = nil;
                switch (type.integerValue) {
                    case 1: body = GJString(GJField(wrap, @"m_nsContent")); break;
                    case 3: body = @"[图片]"; break;
                    case 34: body = @"[语音消息]"; break;
                    case 43: case 62: body = @"[视频]"; break;
                    case 47: body = @"[表情]"; break;
                    case 49: body = @"[分享或文件]"; break;
                    default: body = @"[非文本消息]"; break;
                }
                if (!body.length) continue;
                NSString *realSender = GJString(GJField(wrap, @"m_nsRealChatUsr"));
                if ([username hasSuffix:@"@chatroom"] && incoming && realSender.length) {
                    NSString *prefix = [realSender stringByAppendingString:@":\n"];
                    if ([body hasPrefix:prefix]) body = [body substringFromIndex:prefix.length];
                    from = realSender;
                }
                GJMessage *message = [GJMessage new];
                message.sender = from; message.receiver = to; message.isFromMe = outgoing;
                message.type = type.integerValue; message.timestamp = time.doubleValue;
                message.text = GJClip(body, 1000);
                [messages addObject:message]; [seen addObject:identity];
            }
            if (messages.count) break;
        }
        if (!messages.count) { if (error) *error = GJError(@"已识别聊天，但无法安全读取已加载消息。请先展示最近消息后重试；若仍失败，需要真机确认消息列表字段。未调用未经验证的历史查询接口。"); return context; }
        [messages sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(GJMessage *a, GJMessage *b) {
            return [@(a.timestamp) compare:@(b.timestamp)];
        }];
        NSUInteger count = MIN(MAX((NSUInteger)5, limit), (NSUInteger)50);
        if (messages.count > count) [messages removeObjectsInRange:NSMakeRange(0, messages.count - count)];
        // Also cap total text budget, prioritizing the newest loaded records.
        while (messages.count > 1) {
            NSUInteger total = 0; for (GJMessage *message in messages) total += message.text.length;
            if (total <= 12000) break;
            [messages removeObjectAtIndex:0];
        }
        context.messages = messages;
        return context;
    } @catch (__unused NSException *exception) {
        if (error) *error = GJError(@"微信内部数据结构不兼容，本次读取已停止。"); return nil;
    }
}
@end
