#import <UIKit/UIKit.h>

static void GoutouShowLoadedAlert(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;

        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive &&
                    [scene isKindOfClass:[UIWindowScene class]]) {

                    UIWindowScene *windowScene = (UIWindowScene *)scene;

                    for (UIWindow *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            window = w;
                            break;
                        }
                    }
                }

                if (window) break;
            }
        }

        if (!window) {
            window = [UIApplication sharedApplication].keyWindow;
        }

        UIViewController *vc = window.rootViewController;

        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        if (!vc) return;

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"狗头军师"
                                            message:@"插件已经成功注入微信"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
            [UIAlertAction actionWithTitle:@"知道了"
                                     style:UIAlertActionStyleDefault
                                   handler:nil]];

        [vc presentViewController:alert animated:YES completion:nil];
    });
}

%hook AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    BOOL result = %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        GoutouShowLoadedAlert();
    });

    return result;
}

%end
