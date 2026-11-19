#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RFDialogStyle) {
    RFDialogStyleNormal,
    RFDialogStyleProminent,
    RFDialogStyleDestructive
};

@interface RFDialog : UIView

@property (nonatomic) BOOL dismissesOnBackgroundTap;

- (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                         dark:(BOOL)dark
                      stacked:(BOOL)stacked;
- (UITextField *)addTextFieldWithText:(NSString *)text placeholder:(NSString *)placeholder;
- (UIButton *)addActionWithTitle:(NSString *)title style:(RFDialogStyle)style handler:(void (^)(void))handler;
- (void)showInView:(UIView *)view;
- (void)dismiss;

@end
