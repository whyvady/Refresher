#pragma once
#import <Foundation/Foundation.h>

FOUNDATION_EXTERN NSString *RFAlternativeIcon(NSString *bundleID);
FOUNDATION_EXTERN void RFSetAlternativeIcon(NSString *bundleID, NSString *name);
FOUNDATION_EXTERN NSString *RFAlternativeSignature(void);
FOUNDATION_EXTERN BOOL RFAppIsHidden(NSString *bundleID);
FOUNDATION_EXTERN NSString *RFHiddenSignature(void);
