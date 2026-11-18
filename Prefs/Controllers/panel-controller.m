#import "panel-controller.h"
#import "shared.h"

@implementation RFPanelListController

- (NSString *)plistName {
    return [self.specifier propertyForKey:@"panel"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Reset"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(confirmReset)];
}

- (NSArray *)resetKeys {
    NSMutableSet *keys = [NSMutableSet set];

    for (PSSpecifier *specifier in self.specifiers) {
        NSString *key = [specifier propertyForKey:@"key"];
        if (key) [keys addObject:key];
    }

    NSArray *prefixes = [self.specifier propertyForKey:@"prefixes"];
    if (prefixes.count) {
        NSArray *stored = CFBridgingRelease(CFPreferencesCopyKeyList(RF_PREFS_DOMAIN, kCFPreferencesCurrentUser,
                                                                    kCFPreferencesAnyHost));
        for (NSString *key in stored) {
            for (NSString *prefix in prefixes) {
                if ([key hasPrefix:prefix]) [keys addObject:key];
            }
        }
    }

    return keys.allObjects;
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Settings"
                                                                   message:@"All options in this section will return to their defaults."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [self reset];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reset {
    for (NSString *key in [self resetKeys]) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, RF_PREFS_DOMAIN);
    }
    CFPreferencesAppSynchronize(RF_PREFS_DOMAIN);
    RFPostReload();
    [self reloadSpecifiers];
}

@end
