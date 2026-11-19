#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "assets.h"
#import "clock-face.h"
#import "shared.h"
@interface SBFluidSwitcherIconImageContainerView : UIView
- (id)icon;
- (UIImageView *)imageView;
@end
static NSString *const RFSwitcherClockIdentifier = @"com.apple.mobiletimer";
static NSHashTable<SBFluidSwitcherIconImageContainerView *> *RFSwitcherViews;
static BOOL RFSwitcherIsApplicationIcon(id icon) {
    Class applicationIcon = NSClassFromString(@"SBApplicationIcon");
    return icon && applicationIcon && [icon isKindOfClass:applicationIcon];
}
static BOOL RFSwitcherIsClock(id icon) {
    if (!RFSwitcherIsApplicationIcon(icon) || !RFBoolPreference(@"customClock", YES)) return NO;
    NSString *identifier = ((id (*)(id, SEL))objc_msgSend)(icon, NSSelectorFromString(@"leafIdentifier"));
    return [identifier isEqualToString:RFSwitcherClockIdentifier];
}
static UIImage *RFSwitcherImage(id icon) {
    if (!RFSwitcherIsApplicationIcon(icon)) return nil;
    return ((UIImage *(*)(id, SEL, int))objc_msgSend)(icon, NSSelectorFromString(@"generateIconImage:"), 2);
}
static RFClockFaceView *RFSwitcherFace(UIImageView *imageView) {
    for (UIView *subview in imageView.subviews) {
        if ([subview isKindOfClass:[RFClockFaceView class]]) return (RFClockFaceView *)subview;
    }
    return nil;
}
static UIImage *RFSwitcherReplacement(UIImageView *imageView, UIImage *image) {
    UIView *parent = imageView.superview;
    Class container = NSClassFromString(@"SBFluidSwitcherIconImageContainerView");
    if (!parent || !container || ![parent isKindOfClass:container]) return image;
    SBFluidSwitcherIconImageContainerView *view = (SBFluidSwitcherIconImageContainerView *)parent;
    if ([view imageView] != imageView) return image;
    id icon = [view icon];
    if (RFSwitcherIsClock(icon)) return nil;
    return RFSwitcherImage(icon) ?: image;
}
static void RFSwitcherApply(SBFluidSwitcherIconImageContainerView *view) {
    [RFSwitcherViews addObject:view];
    UIImageView *imageView = [view imageView];
    id icon = [view icon];
    if (!imageView || !icon) return;
    RFClockFaceView *face = RFSwitcherFace(imageView);
    if (RFSwitcherIsClock(icon)) {
        if (!face) {
            face = [[RFClockFaceView alloc] initWithFrame:imageView.bounds];
            face.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [imageView addSubview:face];
        }
        if (imageView.image) imageView.image = nil;
        return;
    }
    [face removeFromSuperview];
    UIImage *image = RFSwitcherImage(icon);
    if (image && imageView.image != image) imageView.image = image;
}
static void RFSwitcherRefresh(SBFluidSwitcherIconImageContainerView *view) {
    [RFSwitcherFace([view imageView]) reloadImages];
    RFSwitcherApply(view);
}
%group Switcher
%hook UIImageView
- (void)setImage:(UIImage *)image {
    %orig(RFSwitcherReplacement(self, image));
}
%end
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
- (void)layoutSubviews {
    %orig;
    RFSwitcherApply(self);
}
- (void)didMoveToWindow {
    %orig;
    RFSwitcherApply(self);
    __weak SBFluidSwitcherIconImageContainerView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        SBFluidSwitcherIconImageContainerView *strongSelf = weakSelf;
        if (strongSelf) RFSwitcherApply(strongSelf);
    });
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
            for (SBFluidSwitcherIconImageContainerView *view in RFSwitcherViews.allObjects) RFSwitcherRefresh(view);
        });
    });
    %init(Switcher);
}
