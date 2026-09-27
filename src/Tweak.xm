#import <UIKit/UIKit.h>
#import "GJManager.h"

// Preserve the verified constructor entry and delayed main-thread startup.
// No private class hooks, message sending hooks, or automatic network requests.
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[GJManager shared] start];
    });
}
