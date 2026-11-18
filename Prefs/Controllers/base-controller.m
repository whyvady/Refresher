#import "base-controller.h"
#import "shared.h"

@implementation RFBaseListController

- (NSString *)plistName {
    return nil;
}

- (NSArray *)buildSpecifiers {
    return [self loadSpecifiersFromPlistName:[self plistName] target:self];
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [[self buildSpecifiers] mutableCopy];
        for (PSSpecifier *specifier in specifiers) {
            if ([specifier propertyForKey:@"key"]) {
                [specifier setProperty:RF_PREFS_DOMAIN_NAME forKey:@"defaults"];
            }
        }
        _specifiers = specifiers;
    }
    return _specifiers;
}

@end
