#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "apps.h"
#import "app-options.h"
#import "assets.h"
#import "icon-views.h"
#import "springboard.h"
#import "shared.h"

static NSCache *RFAppsCache;
static NSMutableDictionary *RFAppsNames;
static NSString *RFAppsSignature;
static __thread BOOL RFAppsIgnoreAlternative;

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

static NSArray *RFAppsCandidates(NSString *bundleID, NSString *displayName) {
    NSString *slug = RFAppsSlug(displayName ?: @"");
    NSString *last = [bundleID.lowercaseString componentsSeparatedByString:@"."].lastObject ?: @"";

    return @[
        RFIconAlias(bundleID) ?: @"",
        RFIconAlias(slug) ?: @"",
        slug,
        last
    ];
}

static UIImage *RFAppsSource(NSString *bundleID, NSString *displayName, NSString *alternative) {
    NSMutableArray *names = [NSMutableArray arrayWithObject:alternative ?: @""];
    [names addObjectsFromArray:RFAppsCandidates(bundleID, displayName)];

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
    NSString *alternative = RFAppsIgnoreAlternative ? nil : RFAlternativeIcon(bundleID);
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%.0fx%.0f@%.0f",
                     RFIconTheme(), bundleID, alternative ?: @"", size.width, size.height, scale];

    id cached = [RFAppsCache objectForKey:key];
    if (cached) return cached == [NSNull null] ? nil : cached;

    UIImage *source = RFAppsSource(bundleID, name, alternative);
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

UIImage *RFAppsDefaultIcon(id icon) {
    RFAppsIgnoreAlternative = YES;
    UIImage *image = ((UIImage *(*)(id, SEL, int))objc_msgSend)(icon, @selector(generateIconImage:), 2);
    RFAppsIgnoreAlternative = NO;
    return image;
}

NSArray *RFAppsOwnIconNames(id icon) {
    SBIcon *source = icon;
    NSString *bundleID = [source leafIdentifier];
    if (!bundleID.length) return @[];

    NSString *name = RFAppsDisplayName(bundleID, [source displayName]);
    for (NSString *candidate in RFAppsCandidates(bundleID, name)) {
        if (!candidate.length) continue;
        if (RFIconImage(nil, RFIconVariantName(candidate, @"Light")) ||
            RFIconImage(nil, RFIconVariantName(candidate, @"Dark"))) {
            return @[candidate];
        }
    }
    return @[];
}

void RFAppsRefresh(NSString *bundleID) {
    RFAppsSignature = RFAlternativeSignature();
    RFIconViewsRefresh(bundleID);
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
