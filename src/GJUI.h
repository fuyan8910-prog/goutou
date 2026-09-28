#import <UIKit/UIKit.h>
static inline void GJNotice(UIViewController *vc, NSString *text) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"军师" message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}
static inline void GJShowText(UIViewController *vc, NSString *title, NSString *text) {
    UIViewController *detail = [UIViewController new]; detail.title = title;
    UITextView *view = [UITextView new]; view.editable = NO; view.text = text;
    view.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    view.backgroundColor = UIColor.systemBackgroundColor; view.textColor = UIColor.labelColor;
    view.textContainerInset = UIEdgeInsetsMake(20, 16, 30, 16); detail.view = view;
    [vc.navigationController pushViewController:detail animated:YES];
}
