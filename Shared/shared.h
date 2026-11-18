#import <Foundation/Foundation.h>

#define RF_PREFS_DOMAIN_NAME @"com.refresher.tweak"
#define RF_PREFS_DOMAIN ((__bridge CFStringRef)RF_PREFS_DOMAIN_NAME)
#define RF_ICONS_ROOT @"/Library/Refresher/Icons/"
#define RF_RELOAD_NOTIFICATION @"com.refresher.tweak/reload"

static inline id RFPreference(NSString *key) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, RF_PREFS_DOMAIN);
    return value ? CFBridgingRelease(value) : nil;
}

static inline BOOL RFBoolPreference(NSString *key, BOOL fallback) {
    id value = RFPreference(key);
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : fallback;
}

static inline NSString *RFStringPreference(NSString *key, NSString *fallback) {
    id value = RFPreference(key);
    return ([value isKindOfClass:[NSString class]] && [value length] > 0) ? value : fallback;
}

static inline BOOL RFIsSpringBoard(void) {
    return [[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"];
}

static inline void RFPostReload(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)RF_RELOAD_NOTIFICATION,
                                         NULL, NULL, YES);
}
