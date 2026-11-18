#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "assets.h"
#import "shared.h"

@interface SBClockApplicationIconImageView : UIView
@end

static NSMutableDictionary<NSString *, id> *RFClockImages;
static NSHashTable<UIView *> *RFClockViews;

static UIImage *RFClockImage(NSString *name) {
    id entry = RFClockImages[name];
    if (!entry) {
        entry = (id)RFIconImage(@"Clock", name) ?: (id)[NSNull null];
        RFClockImages[name] = entry;
    }
    return entry == [NSNull null] ? nil : entry;
}

static CALayer *RFClockLayer(UIView *view, const char *name) {
    Ivar ivar = class_getInstanceVariable([view class], name);
    return ivar ? object_getIvar(view, ivar) : nil;
}

static BOOL RFClockFill(CALayer *layer, NSString *name, CGSize size) {
    UIImage *image = RFClockImage(name);
    if (!layer || !image) return NO;

    CGImageRef cgImage = image.CGImage;
    CGFloat factor = size.height / (CGFloat)CGImageGetHeight(cgImage);

    layer.backgroundColor = NULL;
    layer.cornerRadius = 0;
    if (layer.contents != (__bridge id)cgImage) layer.contents = (__bridge id)cgImage;
    layer.contentsGravity = kCAGravityResize;
    layer.minificationFilter = kCAFilterTrilinear;
    layer.magnificationFilter = kCAFilterLinear;
    layer.anchorPoint = CGPointMake(0.5, 0.5);
    layer.bounds = CGRectMake(0, 0, CGImageGetWidth(cgImage) * factor, size.height);
    layer.position = CGPointMake(size.width / 2.0, size.height / 2.0);
    return YES;
}

static void RFClockApply(UIView *view) {
    CGSize size = view.bounds.size;
    if (size.width < 1 || size.height < 1) return;

    [RFClockViews addObject:view];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    UIImage *background = RFClockImage(@"bg");
    if (background && view.layer.contents != (__bridge id)background.CGImage) {
        view.layer.contents = (__bridge id)background.CGImage;
        view.layer.minificationFilter = kCAFilterTrilinear;
    }

    RFClockFill(RFClockLayer(view, "_hours"), @"hour", size);
    RFClockFill(RFClockLayer(view, "_minutes"), @"min", size);
    RFClockFill(RFClockLayer(view, "_seconds"), @"sec", size);

    CALayer *redDot = RFClockLayer(view, "_redDot");
    CALayer *blackDot = RFClockLayer(view, "_blackDot");
    if (RFClockFill(redDot, @"cap", size)) {
        redDot.hidden = NO;
        blackDot.hidden = YES;
    }

    [CATransaction commit];
}

%group ClockIcon

%hook SBClockApplicationIconImageView

- (void)layoutSubviews {
    %orig;
    RFClockApply(self);
}

- (void)updateClockImages {
    %orig;
    RFClockApply(self);
}

- (void)updateUnanimated {
    %orig;
    RFClockApply(self);
}

%end

%end

%ctor {
    if (!RFIsSpringBoard() || !RFBoolPreference(@"customClock", YES)) return;
    RFClockImages = [NSMutableDictionary dictionary];
    RFClockViews = [NSHashTable weakObjectsHashTable];
    RFIconsOnReload(^{
        [RFClockImages removeAllObjects];
        for (UIView *view in RFClockViews.allObjects) RFClockApply(view);
    });
    %init(ClockIcon);
}
