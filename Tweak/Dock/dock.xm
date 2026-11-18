#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "shared.h"

@interface SBDockView : UIView
@end

static const NSInteger RFDockBlurTag = 0x52464442;
static UIBlurEffectStyle RFDockBlurStyle;

static UIView *RFDockBackground(UIView *dock) {
    Ivar ivar = class_getInstanceVariable([dock class], "_backgroundView");
    return ivar ? object_getIvar(dock, ivar) : nil;
}

static void RFDockApply(UIView *dock) {
    UIView *background = RFDockBackground(dock);
    if (!background) return;

    UIVisualEffectView *blur = (UIVisualEffectView *)[background viewWithTag:RFDockBlurTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:RFDockBlurStyle]];
        blur.tag = RFDockBlurTag;
        blur.userInteractionEnabled = NO;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:blur];
    }

    blur.frame = background.bounds;
    for (UIView *subview in background.subviews) {
        if (subview != blur) subview.hidden = YES;
    }
}

%group DockStyle

%hook SBDockView

- (void)layoutSubviews {
    %orig;
    RFDockApply(self);
}

%end

%end

%ctor {
    if (!RFIsSpringBoard()) return;

    NSString *style = RFStringPreference(@"dockStyle", @"Default");
    if ([style isEqualToString:@"Light"]) {
        RFDockBlurStyle = UIBlurEffectStyleLight;
    } else if ([style isEqualToString:@"Dark"]) {
        RFDockBlurStyle = UIBlurEffectStyleDark;
    } else {
        return;
    }
    %init(DockStyle);
}
