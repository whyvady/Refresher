#import <objc/message.h>
#import "corners.h"

void RFSetCorners(CALayer *layer, CGFloat radius) {
    layer.cornerRadius = radius;
    SEL selector = NSSelectorFromString(@"setContinuousCorners:");
    if ([layer respondsToSelector:selector]) ((void (*)(id, SEL, BOOL))objc_msgSend)(layer, selector, YES);
}
