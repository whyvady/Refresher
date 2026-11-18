#import "icon-views.h"
#import "assets.h"
#import "shared.h"

static NSHashTable *RFIconViewTable;

NSArray *RFIconViews(void) {
    return RFIconViewTable.allObjects ?: @[];
}

void RFIconViewsRefresh(NSString *bundleID) {
    for (SBIconView *view in RFIconViews()) {
        SBIcon *icon = [view icon];
        NSString *identifier = [icon leafIdentifier];
        if ([identifier isEqualToString:RF_CLOCK_BUNDLE_ID]) continue;
        if (bundleID && ![identifier isEqualToString:bundleID]) continue;

        SBIconImageView *imageView = [view _iconImageView];
        [icon purgeCachedImages];
        if ([imageView respondsToSelector:@selector(clearCachedImages)]) [imageView clearCachedImages];
        [icon reloadIconImagePurgingImageCache:YES];
        if ([imageView respondsToSelector:@selector(updateImageAnimated:)]) [imageView updateImageAnimated:NO];
    }
}

%hook SBIconView

- (void)didMoveToWindow {
    %orig;
    if (self.window) [RFIconViewTable addObject:self];
}

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFIconViewTable = [NSHashTable weakObjectsHashTable];
    RFIconsOnReload(^{
        dispatch_async(dispatch_get_main_queue(), ^{
            RFIconViewsRefresh(nil);
        });
    });
    %init;
}
