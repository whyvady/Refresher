#pragma once
#import <UIKit/UIKit.h>

FOUNDATION_EXTERN NSString *RFIconTheme(void);
FOUNDATION_EXTERN UIImage *RFIconImage(NSString *group, NSString *name);
FOUNDATION_EXTERN NSArray *RFIconNames(void);
FOUNDATION_EXTERN void RFIconsOnReload(void (^handler)(void));
FOUNDATION_EXTERN void RFOnPreferencesChange(void (^handler)(void));
FOUNDATION_EXTERN NSString *RFIconAlias(NSString *key);
FOUNDATION_EXTERN NSString *RFIconVariantName(NSString *name, NSString *theme);
FOUNDATION_EXTERN NSString *RFIconVariantTheme(NSString *name);
FOUNDATION_EXTERN NSString *RFIconBaseName(NSString *name);
FOUNDATION_EXTERN BOOL RFIsCustomIcon(NSString *name);
FOUNDATION_EXTERN NSArray *RFCustomIconNames(void);
FOUNDATION_EXTERN NSString *RFCustomIconTitle(NSString *name);
FOUNDATION_EXTERN NSString *RFSaveCustomIcon(UIImage *image, NSString *title);
FOUNDATION_EXTERN void RFRenameCustomIcon(NSString *name, NSString *title);
FOUNDATION_EXTERN void RFRemoveCustomIcon(NSString *name);
