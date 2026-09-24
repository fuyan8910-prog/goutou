#import <UIKit/UIKit.h>

static UIWindow *GoutouGetKeyWindow(void) {
    UIApplication *application = [UIApplication sharedApplication];

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }

        // 如果暂时没有 keyWindow，就找一个正常显示的 window
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            for (UIWindow *window in windowScene.windows) {
                if (!window.hidden && window.alpha > 0.0) {
                    return window;
                }
            }
        }
    }

    return nil;
}

static UIViewController *GoutouTopViewController(UIViewController *vc) {
    if (!vc) {
        return nil;
    }

    if (vc.presentedViewController) {
        return GoutouTopViewController(vc.presentedViewController);
    }

    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        return GoutouTopViewController(nav.visibleViewController);
    }

    if ([vc isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)vc;
        return GoutouTopViewController(tab.selectedViewController);
    }

    return vc;
}

static void GoutouShowLoadedAlert(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = GoutouGetKeyWindow();

        if (!window) {
            return;
        }

        UIViewController *vc =
            GoutouTopViewController(window.rootViewController);

        if (!vc) {
            return;
        }

        UIAlertController *alert =
            [UIAlertController
                alertControllerWithTitle:@"狗头军师"
                message:@"插件已经成功注入微信"
                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *ok =
            [UIAlertAction
                actionWithTitle:@"知道了"
                style:UIAlertActionStyleDefault
                handler:nil];

        [alert addAction:ok];

        [vc presentViewController:alert
                        animated:YES
                      completion:nil];
    });
}

%hook AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    BOOL result = %orig;

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(3.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            GoutouShowLoadedAlert();
        }
    );

    return result;
}

%end
