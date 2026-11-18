#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface RFBaseListController : PSListController

- (NSString *)plistName;
- (NSArray *)buildSpecifiers;

@end
