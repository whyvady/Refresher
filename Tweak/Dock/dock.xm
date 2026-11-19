#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "assets.h"
#import "corners.h"
#import "shared.h"

@interface SBFloatingDockPlatterView : UIView
@end

static const NSInteger RFDockBlurTag = 0x52464442;
static const void *RFDockStyleKey = &RFDockStyleKey;
static NSHashTable<UIView *> *RFDockPlatters;

static NSNumber *RFDockBlurStyle(void) {
    NSString *style = RFStringPreference(@"dockStyle", @"System");
    if ([style isEqualToString:@"System"]) style = RFStringPreference(@"theme", @"Light");
    if ([style isEqualToString:@"Light"]) return @(UIBlurEffectStyleLight);
    if ([style isEqualToString:@"Dark"]) return @(UIBlurEffectStyleDark);
    return nil;
}

static UIView *RFDockBackground(UIView *platter) {
    Ivar ivar = class_getInstanceVariable([platter class], "_backgroundView");
    return ivar ? object_getIvar(platter, ivar) : nil;
}

static void RFDockApply(UIView *platter) {
    UIView *background = RFDockBackground(platter);
    if (!background) return;

    [RFDockPlatters addObject:platter];

    UIVisualEffectView *blur = (UIVisualEffectView *)[background viewWithTag:RFDockBlurTag];
    NSNumber *style = RFDockBlurStyle();

    if (!style) {
        if (blur) {
            [blur removeFromSuperview];
            for (UIView *subview in background.subviews) subview.hidden = NO;
        }
        return;
    }

    if (blur && ![objc_getAssociatedObject(blur, RFDockStyleKey) isEqual:style]) {
        [blur removeFromSuperview];
        blur = nil;
    }

    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:(UIBlurEffectStyle)style.integerValue]];
        blur.tag = RFDockBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(blur, RFDockStyleKey, style, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [background addSubview:blur];
    }

    CGFloat radius = MAX(background.layer.cornerRadius, platter.layer.cornerRadius);
    for (UIView *subview in background.subviews) {
        if (subview != blur) radius = MAX(radius, subview.layer.cornerRadius);
    }

    RFSetCorners(blur.layer, radius);
    blur.frame = background.bounds;
    for (UIView *subview in background.subviews) {
        if (subview != blur) subview.hidden = YES;
    }
}

%group DockStyle

%hook SBFloatingDockPlatterView

- (void)layoutSubviews {
    %orig;
    RFDockApply(self);
}

- (void)didMoveToWindow {
    %orig;
    RFDockApply(self);
}

- (void)setLightStyle:(NSInteger)style {
    %orig;
    RFDockApply(self);
}

%end

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFDockPlatters = [NSHashTable weakObjectsHashTable];
    RFOnPreferencesChange(^{
        for (UIView *platter in RFDockPlatters.allObjects) RFDockApply(platter);
    });
    %init(DockStyle);
}
