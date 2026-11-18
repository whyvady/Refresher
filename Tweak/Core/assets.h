#pragma once
#import <UIKit/UIKit.h>

FOUNDATION_EXTERN NSString *RFIconTheme(void);
FOUNDATION_EXTERN UIImage *RFIconImage(NSString *group, NSString *name);
FOUNDATION_EXTERN NSArray *RFIconNames(void);
FOUNDATION_EXTERN void RFIconsOnReload(void (^handler)(void));
FOUNDATION_EXTERN void RFOnPreferencesChange(void (^handler)(void));
