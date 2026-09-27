#import "GJManager.h"
#import "GJAnalysisViewController.h"
#import "GJWeChatAdapter.h"
#import <QuartzCore/QuartzCore.h>
@interface GJManager ()
@property(nonatomic, strong) UIButton *button;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, weak) UINavigationController *panel;
@end
@implementation GJManager
+ (instancetype)shared { static GJManager *s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [self new]; }); return s; }
- (void)start {
    if (self.timer) return;
    self.button = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.button setTitle:@"狗头军师" forState:UIControlStateNormal];
    self.button.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.button.layer.cornerRadius = 20; self.button.layer.borderWidth = 1;
    self.button.layer.borderColor = UIColor.systemGrayColor.CGColor;
    self.button.accessibilityLabel = @"打开狗头军师，手动分析当前聊天";
    [self.button addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    [self.button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(__unused NSTimer *timer) { [weakSelf attach]; }];
    [self attach];
}
- (UIWindow *)activeWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal && window.rootViewController) return window;
        }
    }
    return nil;
}
- (void)attach {
    UIWindow *window = [self activeWindow];
    if (!window) { self.button.hidden = YES; return; }
    if (self.button.superview != window) {
        [self.button removeFromSuperview]; [window addSubview:self.button];
        self.button.frame = CGRectMake(CGRectGetWidth(window.bounds) - 116, window.safeAreaInsets.top + 100, 104, 40);
    }
    self.button.hidden = self.panel != nil;
    [self clampToWindow:window]; [window bringSubviewToFront:self.button];
}
- (void)clampToWindow:(UIWindow *)window {
    CGRect frame = self.button.frame; UIEdgeInsets inset = window.safeAreaInsets;
    frame.origin.x = MAX(inset.left + 4, MIN(frame.origin.x, CGRectGetWidth(window.bounds) - inset.right - frame.size.width - 4));
    frame.origin.y = MAX(inset.top + 4, MIN(frame.origin.y, CGRectGetHeight(window.bounds) - inset.bottom - frame.size.height - 4));
    self.button.frame = frame;
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    UIWindow *window = self.button.window; if (!window) return;
    CGPoint delta = [gesture translationInView:window];
    self.button.center = CGPointMake(self.button.center.x + delta.x, self.button.center.y + delta.y);
    [gesture setTranslation:CGPointZero inView:window]; [self clampToWindow:window];
}
- (void)open {
    if (self.panel) return;
    UIViewController *source = [GJWeChatAdapter visibleControllerInWindow:self.button.window];
    if (!source || source.isBeingPresented || source.isBeingDismissed || [source isKindOfClass:UIAlertController.class]) return;
    GJAnalysisViewController *analysis = [[GJAnalysisViewController alloc] initWithSourceController:source];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:analysis];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    self.panel = navigation; self.button.hidden = YES;
    [source presentViewController:navigation animated:YES completion:nil];
}
@end
