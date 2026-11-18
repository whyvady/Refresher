#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "shared.h"

@interface UIStatusBarItemView : UIView
@end

@interface UIStatusBarForegroundView : UIView
@end

static const void *RFRequestedHiddenKey = &RFRequestedHiddenKey;
static NSDictionary<NSString *, NSString *> *RFStatusBarItems;
static NSSet<NSString *> *RFHiddenItemClasses;
static NSHashTable<UIView *> *RFForegroundViews;
static Class RFItemClass;
static BOOL RFWriting;

static BOOL RFStatusBarShouldHide(UIView *item) {
    return [RFHiddenItemClasses containsObject:NSStringFromClass([item class])];
}

static void RFStatusBarApply(UIView *item) {
    BOOL requested = [objc_getAssociatedObject(item, RFRequestedHiddenKey) boolValue];
    BOOL hidden = requested || RFStatusBarShouldHide(item);
    if (item.hidden == hidden) return;
    RFWriting = YES;
    item.hidden = hidden;
    RFWriting = NO;
}

static void RFStatusBarApplyAll(UIView *foreground) {
    for (UIView *subview in foreground.subviews) {
        if ([subview isKindOfClass:RFItemClass]) RFStatusBarApply(subview);
    }
}

static void RFStatusBarLoad(void) {
    NSMutableSet<NSString *> *hidden = [NSMutableSet set];
    [RFStatusBarItems enumerateKeysAndObjectsUsingBlock:^(NSString *className, NSString *key, BOOL *stop) {
        if (!RFBoolPreference(key, YES)) [hidden addObject:className];
    }];
    RFHiddenItemClasses = hidden;
}

static void RFStatusBarRefresh(void) {
    for (UIView *foreground in RFForegroundViews.allObjects) {
        RFStatusBarApplyAll(foreground);
        [foreground setNeedsLayout];
    }
}

static void RFStatusBarNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CFPreferencesAppSynchronize((__bridge CFStringRef)RF_PREFS_DOMAIN_NAME);
        RFStatusBarLoad();
        RFStatusBarRefresh();
    });
}

%group StatusBar

%hook UIStatusBarItemView

- (void)setHidden:(BOOL)hidden {
    if (RFWriting) {
        %orig;
        return;
    }
    objc_setAssociatedObject(self, RFRequestedHiddenKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig(hidden || RFStatusBarShouldHide(self));
}

- (void)layoutSubviews {
    %orig;
    RFStatusBarApply(self);
}

- (void)didMoveToWindow {
    %orig;
    RFStatusBarApply(self);
}

%end

%hook UIStatusBarForegroundView

- (void)didMoveToWindow {
    %orig;
    [RFForegroundViews addObject:self];
    RFStatusBarApplyAll(self);
}

- (void)layoutSubviews {
    %orig;
    [RFForegroundViews addObject:self];
    RFStatusBarApplyAll(self);
}

- (void)didAddSubview:(UIView *)subview {
    %orig;
    if ([subview isKindOfClass:RFItemClass]) RFStatusBarApply(subview);
}

%end

%end

%ctor {
    RFItemClass = NSClassFromString(@"UIStatusBarItemView");
    if (!RFItemClass || !NSClassFromString(@"UIStatusBarForegroundView")) return;

    RFStatusBarItems = @{
        @"UIStatusBarTimeItemView": @"showTime",
        @"UIStatusBarDateItemView": @"showDate",
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
    RFForegroundViews = [NSHashTable weakObjectsHashTable];
    RFStatusBarLoad();

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, RFStatusBarNotification, (__bridge CFStringRef)RF_RELOAD_NOTIFICATION, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    %init(StatusBar);
}
