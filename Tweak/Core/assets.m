#import "assets.h"
#import "icon-shape.h"
#import "shared.h"

static NSString *const RFCustomPrefix = @"custom:";
static NSString *const RFCustomRoot = @"/var/mobile/Library/Refresher/Custom/";
static NSString *const RFCustomFallbackTitle = @"Custom";
static const CGFloat RFCustomSide = 512;

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

static NSString *RFCustomIdentifier(NSString *name) {
    return [name substringFromIndex:RFCustomPrefix.length];
}

static NSString *RFCustomPath(NSString *name) {
    return [NSString stringWithFormat:@"%@%@.png", RFCustomRoot, RFCustomIdentifier(name)];
}

static NSString *RFCustomIndexPath(void) {
    return [RFCustomRoot stringByAppendingString:@"index.plist"];
}

static NSDictionary *RFCustomIndex(void) {
    return [NSDictionary dictionaryWithContentsOfFile:RFCustomIndexPath()] ?: @{};
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

NSString *RFIconVariantName(NSString *name, NSString *theme) {
    return [NSString stringWithFormat:@"%@@%@", name, theme.lowercaseString];
}

NSString *RFIconVariantTheme(NSString *name) {
    if ([name hasSuffix:@"@light"]) return @"Light";
    if ([name hasSuffix:@"@dark"]) return @"Dark";
    return nil;
}

NSString *RFIconBaseName(NSString *name) {
    if (!RFIconVariantTheme(name)) return name;
    return [name substringToIndex:[name rangeOfString:@"@" options:NSBackwardsSearch].location];
}

BOOL RFIsCustomIcon(NSString *name) {
    return [name hasPrefix:RFCustomPrefix];
}

UIImage *RFIconImage(NSString *group, NSString *name) {
    if (RFIsCustomIcon(name)) return [UIImage imageWithContentsOfFile:RFCustomPath(name)];

    NSString *theme = (RFIconVariantTheme(name) ?: RFIconTheme()).lowercaseString;
    NSString *base = RFIconBaseName(name);
    NSString *file = group.length
        ? [NSString stringWithFormat:@"%@/%@-%@-%@", group, group.lowercaseString, base, theme]
        : [NSString stringWithFormat:@"%@-%@", base, theme];
    return [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@%@.png", RF_ICONS_ROOT, file]];
}

NSString *RFCustomIconTitle(NSString *name) {
    if (!RFIsCustomIcon(name)) return RFCustomFallbackTitle;
    return RFCustomIndex()[RFCustomIdentifier(name)] ?: RFCustomFallbackTitle;
}

NSArray *RFCustomIconNames(void) {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:RFCustomRoot error:nil];
    NSMutableArray *names = [NSMutableArray array];

    for (NSString *file in files) {
        if (![file.pathExtension isEqualToString:@"png"]) continue;
        [names addObject:[RFCustomPrefix stringByAppendingString:file.stringByDeletingPathExtension]];
    }

    return [names sortedArrayUsingComparator:^NSComparisonResult(NSString *first, NSString *second) {
        return [RFCustomIconTitle(first) localizedCaseInsensitiveCompare:RFCustomIconTitle(second)];
    }];
}

NSString *RFSaveCustomIcon(UIImage *image, NSString *title) {
    if (image.size.width <= 0 || image.size.height <= 0) return nil;

    CGFloat factor = RFCustomSide / MIN(image.size.width, image.size.height);
    CGSize scaled = CGSizeMake(image.size.width * factor, image.size.height * factor);

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(RFCustomSide, RFCustomSide), NO, 1);
    [RFIconShapePath(CGRectMake(0, 0, RFCustomSide, RFCustomSide)) addClip];
    [image drawInRect:CGRectMake((RFCustomSide - scaled.width) / 2, (RFCustomSide - scaled.height) / 2,
                                 scaled.width, scaled.height)];
    UIImage *shaped = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    NSData *data = UIImagePNGRepresentation(shaped);
    if (!data) return nil;

    [[NSFileManager defaultManager] createDirectoryAtPath:RFCustomRoot
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *identifier = [NSUUID UUID].UUIDString;
    NSString *name = [RFCustomPrefix stringByAppendingString:identifier];
    if (![data writeToFile:RFCustomPath(name) atomically:YES]) return nil;

    NSMutableDictionary *index = [RFCustomIndex() mutableCopy];
    index[identifier] = title.length ? title : RFCustomFallbackTitle;
    [index writeToFile:RFCustomIndexPath() atomically:YES];
    return name;
}

void RFRenameCustomIcon(NSString *name, NSString *title) {
    if (!RFIsCustomIcon(name) || !title.length) return;

    NSMutableDictionary *index = [RFCustomIndex() mutableCopy];
    index[RFCustomIdentifier(name)] = title;
    [index writeToFile:RFCustomIndexPath() atomically:YES];
}

void RFRemoveCustomIcon(NSString *name) {
    if (!RFIsCustomIcon(name)) return;

    [[NSFileManager defaultManager] removeItemAtPath:RFCustomPath(name) error:nil];

    NSMutableDictionary *index = [RFCustomIndex() mutableCopy];
    [index removeObjectForKey:RFCustomIdentifier(name)];
    [index writeToFile:RFCustomIndexPath() atomically:YES];
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
