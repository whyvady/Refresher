#import <UIKit/UIKit.h>
#import "assets.h"
#import "shared.h"

static BOOL RFPageDotsHidden;
static NSHashTable *RFPageDotsViews;

static BOOL RFPageDotsMatch(UIView *view) {
    if ([NSStringFromClass([view class]) hasPrefix:@"SBIconListPageControl"]) return YES;

    Class folder = NSClassFromString(@"SBFolderView");
    if (!folder) return NO;

    for (UIView *current = view; current; current = current.superview) {
        if ([current isKindOfClass:folder]) return YES;
    }
    return NO;
}

static BOOL RFPageDotsShouldHide(UIView *view) {
    return RFPageDotsHidden && RFPageDotsMatch(view);
}

%hook UIPageControl

- (void)didMoveToWindow {
    %orig;
    if (!self.window || !RFPageDotsMatch(self)) return;

    [RFPageDotsViews addObject:self];
    if (RFPageDotsHidden) {
        self.hidden = YES;
        self.alpha = 0;
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden || RFPageDotsShouldHide(self));
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(RFPageDotsShouldHide(self) ? 0 : alpha);
}

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFPageDotsViews = [NSHashTable weakObjectsHashTable];
    RFPageDotsHidden = RFBoolPreference(@"hidePageDots", NO);

    RFOnPreferencesChange(^{
        BOOL hidden = RFBoolPreference(@"hidePageDots", NO);
        if (hidden == RFPageDotsHidden) return;
        RFPageDotsHidden = hidden;

        for (UIPageControl *control in RFPageDotsViews.allObjects) {
            control.hidden = hidden;
            control.alpha = hidden ? 0 : 1;
        }
    });

    %init;
}
