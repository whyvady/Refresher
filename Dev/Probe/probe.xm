#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const RFProbePath = @"/var/mobile/refresher-probe.txt";

static BOOL RFProbeMatches(NSString *text, NSString *pattern) {
    NSStringCompareOptions options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    return [text rangeOfString:pattern options:options].location != NSNotFound;
}

static NSDictionary *RFProbeTargets(void) {
    return @{
        @"SBIcon": @"hidden|visible|image|reload|purge|badge|identifier|display",
        @"SBLeafIcon": @"hidden|visible|image|reload|purge|identifier|display",
        @"SBApplicationIcon": @"hidden|visible|image|reload|purge|identifier|display|bundle",
        @"SBIconView": @"label|hidden|visible|image|reload|edit|tap|badge",
        @"SBIconImageView": @"image|update|reload",
        @"SBIconImageCache": @"purge|clear|image|remove|cache",
        @"SBIconModel": @"hidden|visible|layout|reload|tags|add|remove",
        @"SBIconController": @"edit|tap|model|layout|reload|label",
        @"SBIconListView": @"column|row|max|layout|label",
        @"SBIconListModel": @"hidden|visible|max|layout"
    };
}

static void RFProbeClass(NSMutableString *out, Class cls, NSString *pattern) {
    NSMutableArray *chain = [NSMutableArray array];
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        [chain addObject:NSStringFromClass(current)];
    }
    [out appendFormat:@"\n## %@\n", [chain componentsJoinedByString:@" < "]];

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
        [out appendFormat:@"- %@ %s\n", name, method_getTypeEncoding(methods[index])];
    }
    free(methods);
}

static void RFProbeLabelClasses(NSMutableString *out) {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSMutableArray *names = [NSMutableArray array];

    for (unsigned int index = 0; index < count; index++) {
        NSString *name = NSStringFromClass(classes[index]);
        if (RFProbeMatches(name, @"^SB.*Icon.*Label")) [names addObject:name];
    }
    free(classes);

    [names sortUsingSelector:@selector(compare:)];
    for (NSString *name in names) {
        RFProbeClass(out, NSClassFromString(name), @"hidden|alpha|update|image|text|font|visible|layout");
    }
}

static void RFProbeRun(void) {
    NSMutableString *out = [NSMutableString string];
    NSDictionary *targets = RFProbeTargets();

    for (NSString *name in [targets.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        Class cls = NSClassFromString(name);
        if (!cls) {
            [out appendFormat:@"\n## %@ (missing)\n", name];
            continue;
        }
        RFProbeClass(out, cls, targets[name]);
    }

    RFProbeLabelClasses(out);
    [out writeToFile:RFProbePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

%ctor {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        RFProbeRun();
    });
}
