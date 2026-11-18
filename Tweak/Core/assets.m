#import "assets.h"
#import "shared.h"

static NSString *RFCurrentTheme;
static NSMutableArray *RFThemeHandlers;
static NSMutableArray *RFChangeHandlers;

static NSObject *RFAssetsLock(void) {
    static NSObject *lock;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        lock = [NSObject new];
    });
    return lock;
}

static NSString *RFResolveTheme(void) {
    NSString *icons = RFStringPreference(@"iconTheme", @"System");
    if ([icons isEqualToString:@"Light"] || [icons isEqualToString:@"Dark"]) return icons;
    return [RFStringPreference(@"theme", @"Light") isEqualToString:@"Dark"] ? @"Dark" : @"Light";
}

static void RFReloadCallback(CFNotificationCenterRef center, void *observer, CFStringRef name,
                             const void *object, CFDictionaryRef userInfo) {
    CFPreferencesAppSynchronize(RF_PREFS_DOMAIN);
    NSString *theme = RFResolveTheme();
    NSArray *themeHandlers = nil;
    NSArray *changeHandlers;

    @synchronized (RFAssetsLock()) {
        if (![theme isEqualToString:RFCurrentTheme]) {
            RFCurrentTheme = theme;
            themeHandlers = [RFThemeHandlers copy];
        }
        changeHandlers = [RFChangeHandlers copy];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        for (void (^handler)(void) in themeHandlers) handler();
        for (void (^handler)(void) in changeHandlers) handler();
    });
}

static void RFRegisterObserver(void) {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, RFReloadCallback,
                                        (__bridge CFStringRef)RF_RELOAD_NOTIFICATION, NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}

NSString *RFIconTheme(void) {
    @synchronized (RFAssetsLock()) {
        if (!RFCurrentTheme) RFCurrentTheme = RFResolveTheme();
        return RFCurrentTheme;
    }
}

UIImage *RFIconImage(NSString *group, NSString *name) {
    NSString *theme = RFIconTheme().lowercaseString;
    NSString *file = group.length
        ? [NSString stringWithFormat:@"%@/%@-%@-%@", group, group.lowercaseString, name, theme]
        : [NSString stringWithFormat:@"%@-%@", name, theme];
    return [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@%@.png", RF_ICONS_ROOT, file]];
}

NSArray *RFIconNames(void) {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:RF_ICONS_ROOT error:nil];
    NSMutableArray *names = [NSMutableArray array];

    for (NSString *file in files) {
        if ([file hasSuffix:@"-light.png"]) [names addObject:[file substringToIndex:file.length - 10]];
    }
    return [names sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

void RFIconsOnReload(void (^handler)(void)) {
    RFRegisterObserver();

    @synchronized (RFAssetsLock()) {
        if (!RFThemeHandlers) RFThemeHandlers = [NSMutableArray array];
        [RFThemeHandlers addObject:[handler copy]];
    }
}

void RFOnPreferencesChange(void (^handler)(void)) {
    RFRegisterObserver();

    @synchronized (RFAssetsLock()) {
        if (!RFChangeHandlers) RFChangeHandlers = [NSMutableArray array];
        [RFChangeHandlers addObject:[handler copy]];
    }
}

NSString *RFIconAlias(NSString *key) {
    static NSDictionary *aliases;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        aliases = [NSDictionary dictionaryWithContentsOfFile:[RF_ICONS_ROOT stringByAppendingString:@"aliases.plist"]] ?: @{};
    });
    return aliases[key.lowercaseString];
}
