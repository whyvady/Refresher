#import "app-options.h"
#import "keys.h"
#import "shared.h"

static NSString *RFSignature(NSString *prefix) {
    CFPreferencesAppSynchronize(RF_PREFS_DOMAIN);
    NSArray *keys = CFBridgingRelease(CFPreferencesCopyKeyList(RF_PREFS_DOMAIN, kCFPreferencesCurrentUser,
                                                              kCFPreferencesAnyHost));
    NSMutableArray *entries = [NSMutableArray array];

    for (NSString *key in [keys sortedArrayUsingSelector:@selector(compare:)]) {
        if (![key hasPrefix:prefix]) continue;
        id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, RF_PREFS_DOMAIN));
        [entries addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
    }
    return [entries componentsJoinedByString:@"|"];
}

NSString *RFAlternativeIcon(NSString *bundleID) {
    if (!bundleID.length) return nil;
    NSString *name = RFStringPreference([RF_ALTERNATIVE_PREFIX stringByAppendingString:bundleID], @"");
    return name.length ? name : nil;
}

void RFSetAlternativeIcon(NSString *bundleID, NSString *name) {
    NSString *key = [RF_ALTERNATIVE_PREFIX stringByAppendingString:bundleID];
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)name, RF_PREFS_DOMAIN);
    CFPreferencesAppSynchronize(RF_PREFS_DOMAIN);
}

NSString *RFAlternativeSignature(void) {
    return RFSignature(RF_ALTERNATIVE_PREFIX);
}

BOOL RFAppIsHidden(NSString *bundleID) {
    if (!bundleID.length) return NO;
    return RFBoolPreference([RF_HIDDEN_PREFIX stringByAppendingString:bundleID], NO);
}

NSString *RFHiddenSignature(void) {
    return RFSignature(RF_HIDDEN_PREFIX);
}
