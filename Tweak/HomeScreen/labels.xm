#import <UIKit/UIKit.h>
#import "icon-views.h"
#import "assets.h"
#import "shared.h"

@interface SBIconLegibilityLabelView : UIView
@end

@interface SBIconSimpleLabelView : UIImageView
@end

static BOOL RFLabelsHidden;

static void RFLabelsApply(SBIconView *view) {
    UIView *label = [view labelView];
    label.hidden = RFLabelsHidden;
    label.alpha = RFLabelsHidden ? 0 : [view effectiveIconLabelAlpha];
}

%hook SBIconLegibilityLabelView

- (void)setHidden:(BOOL)hidden {
    %orig(hidden || RFLabelsHidden);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(RFLabelsHidden ? 0 : alpha);
}

%end

%hook SBIconSimpleLabelView

- (void)setHidden:(BOOL)hidden {
    %orig(hidden || RFLabelsHidden);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(RFLabelsHidden ? 0 : alpha);
}

%end

%hook SBIconView

- (void)layoutSubviews {
    %orig;
    if (RFLabelsHidden) RFLabelsApply(self);
}

- (void)_updateLabel {
    %orig;
    if (RFLabelsHidden) RFLabelsApply(self);
}

- (BOOL)shouldShowLabelAccessoryView {
    return RFLabelsHidden ? NO : %orig;
}

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFLabelsHidden = RFBoolPreference(@"hideLabels", NO);

    RFOnPreferencesChange(^{
        BOOL hidden = RFBoolPreference(@"hideLabels", NO);
        if (hidden == RFLabelsHidden) return;
        RFLabelsHidden = hidden;
        for (SBIconView *view in RFIconViews()) RFLabelsApply(view);
    });

    %init;
}
