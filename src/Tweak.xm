#import <UIKit/UIKit.h>

static void GoutouShowAlert(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *targetWindow = nil;

        if (@available(iOS 13.0, *)) {
            NSSet *scenes = [UIApplication sharedApplication].connectedScenes;

            for (UIScene *scene in scenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) {
                    continue;
                }

                UIWindowScene *windowScene = (UIWindowScene *)scene;

                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        targetWindow = window;
                        break;
                    }
                }

                if (targetWindow) {
                    break;
                }
            }
        }

        if (!targetWindow || !targetWindow.rootViewController) {
            // UI 可能还没有初始化完成，再等两秒
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(2.0 * NSEC_PER_SEC)),
                dispatch_get_main_queue(),
                ^{
                    GoutouShowAlert();
                }
            );

            return;
        }

        UIViewController *vc = targetWindow.rootViewController;

        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        UIAlertController *alert =
            [UIAlertController
                alertControllerWithTitle:@"狗头军师"
                message:@"GoutouJunshi.dylib 已成功加载"
                preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
            [UIAlertAction
                actionWithTitle:@"确定"
                style:UIAlertActionStyleDefault
                handler:nil]];

        [vc presentViewController:alert
                        animated:YES
                      completion:nil];
    });
}

%ctor {
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(5.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            GoutouShowAlert();
        }
    );
}
