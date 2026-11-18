#pragma once
#import <UIKit/UIKit.h>

#define RF_CLOCK_BUNDLE_ID @"com.apple.mobiletimer"

@interface SBIcon : NSObject
- (NSString *)leafIdentifier;
- (NSString *)displayName;
- (void)purgeCachedImages;
- (void)reloadIconImagePurgingImageCache:(BOOL)purge;
@end

@interface SBApplicationIcon : SBIcon
@end

@interface SBIconImageView : UIView
- (void)clearCachedImages;
- (void)updateImageAnimated:(BOOL)animated;
@end

@interface SBIconView : UIView
- (SBIcon *)icon;
- (SBIconImageView *)_iconImageView;
- (UIView *)labelView;
- (BOOL)isEditing;
- (CGFloat)effectiveIconLabelAlpha;
@end

@interface SBIconModel : NSObject
- (void)layout;
@end

@interface SBIconController : UIViewController
+ (instancetype)sharedInstance;
- (SBIconModel *)model;
- (BOOL)relayout;
@end
