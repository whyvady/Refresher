#import <UIKit/UIKit.h>
#import "shared.h"

@interface UIStatusBarItemView : UIView
@end

static NSSet<NSString *> *RFHiddenItemClasses;

static NSDictionary<NSString *, NSString *> *RFStatusBarItems(void) {
    return @{
        @"UIStatusBarTimeItemView": @"showTime",
        @"UIStatusBarBatteryItemView": @"showBattery",
        @"UIStatusBarBatteryPercentItemView": @"showBatteryPercent",
        @"UIStatusBarSignalStrengthItemView": @"showSignal",
        @"UIStatusBarServiceItemView": @"showCarrier",
        @"UIStatusBarDataNetworkItemView": @"showWiFi",
        @"UIStatusBarBluetoothItemView": @"showBluetooth",
        @"UIStatusBarAirplaneModeItemView": @"showAirplaneMode",
        @"UIStatusBarQuietModeItemView": @"showDoNotDisturb",
        @"UIStatusBarAlarmItemView": @"showAlarm",
        @"UIStatusBarLocationItemView": @"showLocation",
        @"UIStatusBarRotationLockItemView": @"showRotationLock",
        @"UIStatusBarActivityItemView": @"showActivity"
    };
}

static BOOL RFStatusBarShouldHide(id item) {
    return [RFHiddenItemClasses containsObject:NSStringFromClass([item class])];
}

%group StatusBar

%hook UIStatusBarItemView

- (void)layoutSubviews {
    %orig;
    if (RFStatusBarShouldHide(self)) self.hidden = YES;
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden || RFStatusBarShouldHide(self));
}

%end

%end

%ctor {
    NSMutableSet<NSString *> *hidden = [NSMutableSet set];
    [RFStatusBarItems() enumerateKeysAndObjectsUsingBlock:^(NSString *className, NSString *key, BOOL *stop) {
        if (!RFBoolPreference(key, YES)) [hidden addObject:className];
    }];

    if (hidden.count == 0 || !NSClassFromString(@"UIStatusBarItemView")) return;
    RFHiddenItemClasses = hidden;
    %init(StatusBar);
}
