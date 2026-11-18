#import <UIKit/UIKit.h>
#import "app-options.h"
#import "assets.h"
#import "icon-views.h"
#import "springboard.h"
#import "shared.h"

static NSCache *RFAppsCache;
static NSMutableDictionary *RFAppsNames;
static NSString *RFAppsSignature;

static NSString *RFAppsSlug(NSString *text) {
    NSCharacterSet *separators = [NSCharacterSet alphanumericCharacterSet].invertedSet;
    NSArray *parts = [text.lowercaseString componentsSeparatedByCharactersInSet:separators];
    parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    return [parts componentsJoinedByString:@"-"];
}

static NSString *RFAppsDisplayName(NSString *bundleID, NSString *displayName) {
    @synchronized (RFAppsNames) {
        if (displayName.length) RFAppsNames[bundleID] = displayName;
        return RFAppsNames[bundleID];
    }
}

static UIImage *RFAppsSource(NSString *bundleID, NSString *displayName) {
    NSString *slug = RFAppsSlug(displayName ?: @"");
    NSString *last = [bundleID.lowercaseString componentsSeparatedByString:@"."].lastObject ?: @"";

    NSArray *names = @[
        RFAlternativeIcon(bundleID) ?: @"",
        RFIconAlias(bundleID) ?: @"",
        RFIconAlias(slug) ?: @"",
        slug,
        last
    ];

    for (NSString *name in names) {
        if (!name.length) continue;
        UIImage *image = RFIconImage(nil, name);
        if (image) return image;
    }
    return nil;
}

static UIImage *RFAppsCompose(NSString *bundleID, NSString *displayName, CGSize size, CGFloat scale) {
    if (!bundleID.length || size.width <= 0 || size.height <= 0) return nil;

    NSString *name = RFAppsDisplayName(bundleID, displayName);
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%.0fx%.0f@%.0f",
                     RFIconTheme(), bundleID, RFAlternativeIcon(bundleID) ?: @"", size.width, size.height, scale];

    id cached = [RFAppsCache objectForKey:key];
    if (cached) return cached == [NSNull null] ? nil : cached;

    UIImage *source = RFAppsSource(bundleID, name);
    UIImage *result = nil;

    if (source) {
        UIGraphicsBeginImageContextWithOptions(size, NO, scale);
        CGContextSetInterpolationQuality(UIGraphicsGetCurrentContext(), kCGInterpolationHigh);
        [source drawInRect:CGRectMake(0, 0, size.width, size.height)];
        result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    if (result) {
        [RFAppsCache setObject:result forKey:key];
    } else if (name.length) {
        [RFAppsCache setObject:[NSNull null] forKey:key];
    }
    return result;
}

static UIImage *RFAppsApply(SBIcon *icon, NSString *bundleID, UIImage *original) {
    if (!original || !bundleID.length) return original;

    NSString *name = RFAppsDisplayName(bundleID, nil);
    if (!name.length) name = [icon displayName];

    return RFAppsCompose(bundleID, name, original.size, original.scale) ?: original;
}

%hook SBApplicationIcon

- (UIImage *)__loadUnmaskedIconImageForFormat:(int)format bundleIdentifier:(NSString *)bundleID {
    return RFAppsApply(self, bundleID, %orig);
}

- (UIImage *)generateIconImage:(int)format {
    return RFAppsApply(self, [self leafIdentifier], %orig);
}

- (UIImage *)getUnmaskedIconImage:(int)format {
    return RFAppsApply(self, [self leafIdentifier], %orig);
}

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFAppsCache = [NSCache new];
    RFAppsNames = [NSMutableDictionary dictionary];
    RFAppsSignature = RFAlternativeSignature();

    RFIconsOnReload(^{
        [RFAppsCache removeAllObjects];
    });

    RFOnPreferencesChange(^{
        NSString *signature = RFAlternativeSignature();
        if ([signature isEqualToString:RFAppsSignature]) return;
        RFAppsSignature = signature;
        RFIconViewsRefresh(nil);
    });

    %init;
}
