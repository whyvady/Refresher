#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "assets.h"
#import "shared.h"

@interface SBFluidSwitcherIconImageContainerView : UIView
- (id)icon;
- (UIImageView *)imageView;
@end

static NSHashTable<SBFluidSwitcherIconImageContainerView *> *RFSwitcherViews;

static UIImage *RFSwitcherImage(id icon) {
    Class applicationIcon = NSClassFromString(@"SBApplicationIcon");
    if (!icon || !applicationIcon || ![icon isKindOfClass:applicationIcon]) return nil;
    return ((UIImage *(*)(id, SEL, int))objc_msgSend)(icon, NSSelectorFromString(@"generateIconImage:"), 2);
}

static void RFSwitcherApply(SBFluidSwitcherIconImageContainerView *view) {
    UIImageView *imageView = [view imageView];
    UIImage *image = RFSwitcherImage([view icon]);
    if (!imageView || !image) return;
    [RFSwitcherViews addObject:view];
    imageView.image = image;
}

%group Switcher

%hook SBFluidSwitcherIconImageContainerView

- (void)updateIcon {
    %orig;
    RFSwitcherApply(self);
}

- (void)iconImageDidUpdate:(id)update {
    %orig;
    RFSwitcherApply(self);
}

- (void)_configureIconImageView:(id)view {
    %orig;
    RFSwitcherApply(self);
}

- (void)didMoveToWindow {
    %orig;
    RFSwitcherApply(self);
}

- (void)_crossfadeToIconImage:(UIImage *)image {
    %orig(RFSwitcherImage([self icon]) ?: image);
}

%end

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFSwitcherViews = [NSHashTable weakObjectsHashTable];
    RFOnPreferencesChange(^{
        dispatch_async(dispatch_get_main_queue(), ^{
            for (SBFluidSwitcherIconImageContainerView *view in RFSwitcherViews.allObjects) RFSwitcherApply(view);
        });
    });
    %init(Switcher);
}
