#import "apps-controller.h"
#import "keys.h"
#import "shared.h"

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSArray *appTags;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@implementation RFAppsListController

- (NSArray *)installedApps {
    LSApplicationWorkspace *workspace = [NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace];
    NSMutableArray *apps = [NSMutableArray array];

    for (LSApplicationProxy *proxy in [workspace allInstalledApplications]) {
        NSArray *tags = [proxy respondsToSelector:@selector(appTags)] ? proxy.appTags : nil;
        if (!proxy.localizedName.length || [tags containsObject:@"hidden"]) continue;
        [apps addObject:proxy];
    }

    return [apps sortedArrayUsingComparator:^NSComparisonResult(LSApplicationProxy *first, LSApplicationProxy *second) {
        return [first.localizedName localizedCaseInsensitiveCompare:second.localizedName];
    }];
}

- (PSSpecifier *)specifierForApp:(LSApplicationProxy *)proxy {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:proxy.localizedName
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSwitchCell
                                                              edit:nil];
    [specifier setProperty:[RF_HIDDEN_PREFIX stringByAppendingString:proxy.applicationIdentifier] forKey:@"key"];
    [specifier setProperty:@NO forKey:@"default"];
    [specifier setProperty:RF_RELOAD_NOTIFICATION forKey:@"PostNotification"];
    return specifier;
}

- (NSArray *)buildSpecifiers {
    NSMutableArray *specifiers = [NSMutableArray array];
    [specifiers addObject:[PSSpecifier groupSpecifierWithName:@"Turn on to hide an app from the Home Screen"]];

    for (LSApplicationProxy *proxy in [self installedApps]) {
        [specifiers addObject:[self specifierForApp:proxy]];
    }
    return specifiers;
}

@end
