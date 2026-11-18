#import <UIKit/UIKit.h>
#import "app-options.h"
#import "assets.h"
#import "springboard.h"
#import "shared.h"

@interface SBCalendarApplicationIcon : SBApplicationIcon
@end

static NSObject *RFCalendarLock;
static NSString *RFCalendarKey;
static UIImage *RFCalendarCache;

static UIImage *RFCalendarCompose(CGSize size, CGFloat scale) {
    NSDateComponents *components = [[NSCalendar autoupdatingCurrentCalendar]
        components:(NSCalendarUnitWeekday | NSCalendarUnitDay) fromDate:[NSDate date]];
    NSInteger weekday = components.weekday;
    NSInteger day = components.day;
    if (weekday < 1 || weekday > 7 || day < 1 || day > 31) return nil;

    NSString *key = [NSString stringWithFormat:@"%@|%ld|%ld|%.0fx%.0f@%.0f",
                     RFIconTheme(), (long)weekday, (long)day, size.width, size.height, scale];

    @synchronized (RFCalendarLock) {
        if (RFCalendarCache && [RFCalendarKey isEqualToString:key]) return RFCalendarCache;
    }

    UIImage *background = RFIconImage(@"Calendar", @"bg");
    if (!background) return nil;

    UIImage *weekdayImage = RFIconImage(@"Calendar", [NSString stringWithFormat:@"wd-%ld", (long)weekday]);
    UIImage *dayImage = RFIconImage(@"Calendar", [NSString stringWithFormat:@"num-%ld", (long)day]);

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextSetInterpolationQuality(UIGraphicsGetCurrentContext(), kCGInterpolationHigh);
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    [background drawInRect:rect];
    [weekdayImage drawInRect:rect];
    [dayImage drawInRect:rect];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    @synchronized (RFCalendarLock) {
        RFCalendarKey = key;
        RFCalendarCache = result;
    }
    return result;
}

%hook SBCalendarApplicationIcon

- (UIImage *)generateIconImage:(int)format {
    UIImage *original = %orig;
    if (!original || RFAlternativeIcon([self leafIdentifier])) return original;
    return RFCalendarCompose(original.size, original.scale) ?: original;
}

%end

%ctor {
    if (!RFIsSpringBoard() || !RFBoolPreference(@"customCalendar", YES)) return;
    RFCalendarLock = [NSObject new];
    RFIconsOnReload(^{
        @synchronized (RFCalendarLock) {
            RFCalendarKey = nil;
            RFCalendarCache = nil;
        }
    });
    %init;
}
