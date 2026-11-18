#import <UIKit/UIKit.h>
#import "app-options.h"
#import "assets.h"
#import "icon-views.h"
#import "springboard.h"
#import "shared.h"

static NSCache *RFAppsCache;
static NSString *RFAppsSignature;

static NSString *RFAppsSlug(NSString *text) {
    NSCharacterSet *separators = [NSCharacterSet alphanumericCharacterSet].invertedSet;
    NSArray *parts = [text.lowercaseString componentsSeparatedByCharactersInSet:separators];
    parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    return [parts componentsJoinedByString:@"-"];
}

static UIImage *RFAppsSource(NSString *bundleID, NSString *displayName) {
    NSString *last = [bundleID.lowercaseString componentsSeparatedByString:@"."].lastObject;
    NSMutableArray *names = [NSMutableArray array];

    NSString *alternative = RFAlternativeIcon(bundleID);
    if (alternative) [names addObject:alternative];
    [names addObject:RFAppsSlug(displayName ?: @"")];
    [names addObject:last];

    for (NSString *name in names) {
        if (!name.length) continue;
        UIImage *image = RFIconImage(nil, name);
        if (image) return image;
    }
    return nil;
}

static UIImage *RFAppsCompose(NSString *bundleID, NSString *displayName, CGSize size, CGFloat scale) {
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%.0fx%.0f@%.0f",
                     RFIconTheme(), bundleID, RFAlternativeIcon(bundleID) ?: @"", size.width, size.height, scale];

    id cached = [RFAppsCache objectForKey:key];
    if (cached) return cached == [NSNull null] ? nil : cached;

    UIImage *source = RFAppsSource(bundleID, displayName);
    UIImage *result = nil;

    if (source) {
        UIGraphicsBeginImageContextWithOptions(size, NO, scale);
        CGContextSetInterpolationQuality(UIGraphicsGetCurrentContext(), kCGInterpolationHigh);
        [source drawInRect:CGRectMake(0, 0, size.width, size.height)];
        result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    id entry = result;
    if (!entry) entry = [NSNull null];
    [RFAppsCache setObject:entry forKey:key];
    return result;
}

%hook SBApplicationIcon

- (UIImage *)generateIconImage:(int)format {
    UIImage *original = %orig;
    if (!original) return original;

    NSString *bundleID = [self leafIdentifier];
    if (!bundleID.length) return original;

    return RFAppsCompose(bundleID, [self displayName], original.size, original.scale) ?: original;
}

%end

%ctor {
    if (!RFIsSpringBoard()) return;
    RFAppsCache = [NSCache new];
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
