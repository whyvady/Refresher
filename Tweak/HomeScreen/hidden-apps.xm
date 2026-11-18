#import <UIKit/UIKit.h>
#import "app-options.h"
#import "assets.h"
#import "assets.h"
#import "springboard.h"
#import "shared.h"

static NSString *RFHiddenCurrent;

%hook SBIconModel

- (BOOL)isIconVisible:(SBIcon *)icon {
    if (RFAppIsHidden([icon leafIdentifier])) return NO;
    return %orig;
}

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFHiddenCurrent = RFHiddenSignature();

    RFOnPreferencesChange(^{
        NSString *signature = RFHiddenSignature();
        if ([signature isEqualToString:RFHiddenCurrent]) return;
        RFHiddenCurrent = signature;

        SBIconController *controller = [%c(SBIconController) sharedInstance];
        [[controller model] layout];
        [controller relayout];
    });

    %init;
}
