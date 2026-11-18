#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger RFProbeLimit = 3;
static NSString *const RFProbeTrigger = @"/var/mobile/refresher-dump";

@interface UIWindow (RFProbe)
+ (NSArray *)allWindowsIncludingInternalWindows:(BOOL)internal onlyVisibleWindows:(BOOL)visible;
@end

static dispatch_source_t RFProbeTimer;
static NSMutableString *RFProbeTree;
static NSMutableString *RFProbeDetails;
static NSMutableDictionary *RFProbeCounts;
static NSMutableSet *RFProbeDumped;

static BOOL RFProbeMatches(NSString *text, NSString *pattern) {
    NSStringCompareOptions options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    return [text rangeOfString:pattern options:options].location != NSNotFound;
}

static NSArray *RFProbeRules(void) {
    return @[
        @[@"Switcher|AppLayout|Deck", @"icon|image"],
        @[@"Dock", @"background|blur|material|effect|style|hidden|alpha"],
        @[@"PageControl", @"hidden|alpha|dots|page"]
    ];
}

static void RFProbeClass(NSMutableString *out, Class cls, NSString *pattern) {
    NSString *kind = class_isMetaClass(cls) ? @"+" : @"-";
    NSMutableArray *chain = [NSMutableArray array];
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        [chain addObject:NSStringFromClass(current)];
    }
    [out appendFormat:@"\n## %@ %@\n", kind, [chain componentsJoinedByString:@" < "]];

    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    for (unsigned int index = 0; index < count; index++) {
        NSString *name = @(ivar_getName(ivars[index]));
        if (!RFProbeMatches(name, pattern)) continue;
        [out appendFormat:@"ivar %@ %s\n", name, ivar_getTypeEncoding(ivars[index])];
    }
    free(ivars);

    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int index = 0; index < count; index++) {
        NSString *name = NSStringFromSelector(method_getName(methods[index]));
        if (!RFProbeMatches(name, pattern)) continue;
        [out appendFormat:@"%@ %@ %s\n", kind, name, method_getTypeEncoding(methods[index])];
    }
    free(methods);
}

static void RFProbeWalk(UIView *view, NSInteger depth) {
    Class cls = [view class];
    NSString *name = NSStringFromClass(cls);
    NSInteger seen = [RFProbeCounts[name] integerValue];
    RFProbeCounts[name] = @(seen + 1);

    if (seen < RFProbeLimit) {
        NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
        [RFProbeTree appendFormat:@"%@%@ %@ hidden=%d alpha=%.2f", indent, name,
                                  NSStringFromCGRect(view.frame), view.hidden, view.alpha];
        if ([view isKindOfClass:[UIImageView class]]) {
            UIImage *image = ((UIImageView *)view).image;
            [RFProbeTree appendFormat:@" image=%@ @%.0fx", NSStringFromCGSize(image.size), image.scale];
        }
        [RFProbeTree appendString:@"\n"];

        if (![RFProbeDumped containsObject:name]) {
            [RFProbeDumped addObject:name];
            for (NSArray *rule in RFProbeRules()) {
                if (RFProbeMatches(name, rule[0])) RFProbeClass(RFProbeDetails, cls, rule[1]);
            }
        }
    }

    for (UIView *subview in view.subviews) RFProbeWalk(subview, depth + 1);
}

static void RFProbeDump(NSString *label) {
    RFProbeTree = [NSMutableString string];
    RFProbeDetails = [NSMutableString string];
    RFProbeCounts = [NSMutableDictionary dictionary];
    RFProbeDumped = [NSMutableSet set];

    NSArray *windows = nil;
    if ([UIWindow respondsToSelector:@selector(allWindowsIncludingInternalWindows:onlyVisibleWindows:)]) {
        windows = [UIWindow allWindowsIncludingInternalWindows:YES onlyVisibleWindows:YES];
    }
    if (!windows.count) windows = [UIApplication sharedApplication].windows;

    for (UIWindow *window in windows) {
        [RFProbeTree appendFormat:@"\n# WINDOW %@ level=%.0f frame=%@\n", NSStringFromClass([window class]),
                                  window.windowLevel, NSStringFromCGRect(window.frame)];
        RFProbeWalk(window, 0);
    }

    NSMutableString *out = [NSMutableString stringWithFormat:@"# %@\n%@\n# DETAILS\n%@", label, RFProbeTree, RFProbeDetails];
    RFProbeClass(out, object_getClass([UIImage class]), @"applicationIcon|iconImage");

    NSString *path = [NSString stringWithFormat:@"/var/mobile/refresher-probe-%@.txt", label];
    [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void RFProbePoll(void) {
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:RFProbeTrigger]) return;

    NSString *content = [NSString stringWithContentsOfFile:RFProbeTrigger encoding:NSUTF8StringEncoding error:nil];
    NSString *label = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [manager removeItemAtPath:RFProbeTrigger error:nil];

    RFProbeDump(label.length ? label : @"dump");
}

%ctor {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;

    RFProbeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(RFProbeTimer, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                              NSEC_PER_SEC, NSEC_PER_SEC / 10);
    dispatch_source_set_event_handler(RFProbeTimer, ^{
        RFProbePoll();
    });
    dispatch_resume(RFProbeTimer);
}
