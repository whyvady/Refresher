#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "apps.h"
#import "app-options.h"
#import "icon-views.h"
#import "picker-controller.h"
#import "shared.h"

@interface SBFloatingDockPlatterView : UIView
@end

static const void *RFPickerRecognizerKey = &RFPickerRecognizerKey;
static const CGFloat RFPickerCloseBoxZone = 30;

static __weak UIView *RFPickerDock;

static CGRect RFPickerDockRect(void) {
    UIView *dock = RFPickerDock;
    if (!dock.window) return CGRectZero;

    UIView *background = nil;
    @try {
        background = [dock valueForKey:@"_backgroundView"];
    } @catch (NSException *exception) {
    }

    UIView *target = (background.window && background.bounds.size.width > 0) ? background : dock;
    return [target convertRect:target.bounds toCoordinateSpace:[UIScreen mainScreen].coordinateSpace];
}

static BOOL RFPickerAllowed(SBIconView *view) {
    if (!RFBoolPreference(@"altIcons", YES) || ![view isEditing]) return NO;

    SBIcon *icon = [view icon];
    if (![icon isKindOfClass:%c(SBApplicationIcon)]) return NO;
    return ![[icon leafIdentifier] isEqualToString:RF_CLOCK_BUNDLE_ID];
}

static void RFPickerPresent(SBIconView *view) {
    SBIcon *icon = [view icon];
    NSString *bundleID = [icon leafIdentifier];
    if (!bundleID.length) return;

    [RFPickerController presentWithTitle:[icon displayName]
                                selected:RFAlternativeIcon(bundleID)
                             defaultIcon:RFAppsDefaultIcon(icon)
                             ownNames:RFAppsOwnIconNames(icon)
                                  anchor:^CGRect {
        return RFPickerDockRect();
    }
                              completion:^(NSString *name) {
        RFSetAlternativeIcon(bundleID, name);
        RFAppsRefresh(bundleID);
    }];
}

@interface RFPickerGestureHandler : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;
@end

@implementation RFPickerGestureHandler

+ (instancetype)shared {
    static RFPickerGestureHandler *handler;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        handler = [RFPickerGestureHandler new];
    });
    return handler;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    SBIconView *view = (SBIconView *)recognizer.view;
    if (!RFPickerAllowed(view)) return NO;

    UIView *imageView = [view _iconImageView];
    CGPoint point = [touch locationInView:imageView];
    if (!CGRectContainsPoint(imageView.bounds, point)) return NO;
    return point.x > RFPickerCloseBoxZone || point.y > RFPickerCloseBoxZone;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) return;
    RFPickerPresent((SBIconView *)recognizer.view);
}

@end

%hook SBFloatingDockPlatterView

- (void)didMoveToWindow {
    %orig;
    if (self.window) RFPickerDock = self;
}

%end

%hook SBIconView

- (void)didMoveToWindow {
    %orig;
    if (!self.window || objc_getAssociatedObject(self, RFPickerRecognizerKey)) return;

    RFPickerGestureHandler *handler = [RFPickerGestureHandler shared];
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:handler
                                                                                  action:@selector(handleTap:)];
    recognizer.delegate = handler;
    recognizer.cancelsTouchesInView = NO;
    [self addGestureRecognizer:recognizer];
    objc_setAssociatedObject(self, RFPickerRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    %init;
}
