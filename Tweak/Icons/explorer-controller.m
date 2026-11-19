#import "explorer-controller.h"
#import <ImageIO/ImageIO.h>
#import "assets.h"
#import "corners.h"

static NSString *const RFExplorerCellIdentifier = @"RFExplorerCell";
static NSString *const RFExplorerStart = @"/var/mobile";
static const CGFloat RFExplorerHeaderHeight = 52;
static const CGFloat RFExplorerButtonWidth = 72;
static const CGFloat RFExplorerButtonMargin = 8;
static const CGFloat RFExplorerFieldHeight = 34;
static const CGFloat RFExplorerFieldPadding = 10;
static const CGFloat RFExplorerThumbnailSide = 40;
static const CGFloat RFExplorerRowHeight = 56;

static NSSet *RFExplorerImageExtensions(void) {
    static NSSet *extensions;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        extensions = [NSSet setWithArray:@[@"png", @"jpg", @"jpeg", @"gif", @"tif", @"tiff", @"bmp", @"heic"]];
    });
    return extensions;
}

static dispatch_queue_t RFExplorerQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        queue = dispatch_queue_create("com.refresher.tweak.thumbnails", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static UIImage *RFExplorerPlaceholder(void) {
    static UIImage *placeholder;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        CGSize size = CGSizeMake(RFExplorerThumbnailSide, RFExplorerThumbnailSide);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0);
        [[UIColor colorWithWhite:0.5 alpha:0.2] setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:6] fill];
        placeholder = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return placeholder;
}

static UIImage *RFExplorerThumbnail(NSString *path) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!source) return nil;

    CGFloat scale = [UIScreen mainScreen].scale;
    NSDictionary *options = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize: @(RFExplorerThumbnailSide * scale)
    };
    CGImageRef cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (!cgImage) return nil;

    UIImage *thumbnail = [UIImage imageWithCGImage:cgImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);

    CGSize box = CGSizeMake(RFExplorerThumbnailSide, RFExplorerThumbnailSide);
    UIGraphicsBeginImageContextWithOptions(box, NO, scale);
    [thumbnail drawInRect:CGRectMake((box.width - thumbnail.size.width) / 2,
                                     (box.height - thumbnail.size.height) / 2,
                                     thumbnail.size.width, thumbnail.size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@interface RFExplorerCell : UITableViewCell
@property (nonatomic, copy) NSString *path;
@end

@implementation RFExplorerCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.selectedBackgroundView = [UIView new];

    return self;
}

@end

@interface RFExplorerController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@end

@implementation RFExplorerController {
    NSString *_path;
    NSArray *_entries;
    NSUInteger _folderCount;
    NSCache *_thumbnails;
    BOOL _dark;
    void (^_handler)(UIImage *);
    UIButton *_upButton;
    UIButton *_closeButton;
    UITextField *_field;
    UILabel *_fieldLabel;
    UIView *_separator;
    UITableView *_table;
}

- (instancetype)initWithHandler:(void (^)(UIImage *image))handler {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;

    _path = RFExplorerStart;
    _handler = [handler copy];
    _thumbnails = [NSCache new];
    _dark = [RFIconTheme() isEqualToString:@"Dark"];

    return self;
}

- (UIColor *)textColor {
    return _dark ? [UIColor whiteColor] : [UIColor blackColor];
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = _dark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor];

    _upButton = [self buttonWithTitle:@"Up" action:@selector(goUp)];
    _closeButton = [self buttonWithTitle:@"Close" action:@selector(closeTapped)];

    UIView *spacer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, RFExplorerFieldPadding, 1)];

    _field = [UITextField new];
    _field.delegate = self;
    _field.font = [UIFont systemFontOfSize:15];
    _field.textColor = [UIColor clearColor];
    _field.textAlignment = NSTextAlignmentCenter;
    _field.placeholder = @"Path";
    _field.clearButtonMode = UITextFieldViewModeWhileEditing;
    _field.leftView = spacer;
    _field.leftViewMode = UITextFieldViewModeAlways;
    _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _field.autocorrectionType = UITextAutocorrectionTypeNo;
    _field.spellCheckingType = UITextSpellCheckingTypeNo;
    _field.keyboardType = UIKeyboardTypeURL;
    _field.returnKeyType = UIReturnKeyGo;
    _field.keyboardAppearance = _dark ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    _field.backgroundColor = _dark ? [UIColor colorWithWhite:1 alpha:0.12] : [UIColor colorWithWhite:0 alpha:0.06];
    _field.layer.borderWidth = 1;
    _field.layer.borderColor = (_dark ? [UIColor colorWithWhite:1 alpha:0.22]
                                      : [UIColor colorWithWhite:0 alpha:0.16]).CGColor;
    RFSetCorners(_field.layer, 10);
    [self.view addSubview:_field];

    _fieldLabel = [UILabel new];
    _fieldLabel.font = _field.font;
    _fieldLabel.textColor = [self textColor];
    _fieldLabel.textAlignment = NSTextAlignmentCenter;
    _fieldLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    _fieldLabel.userInteractionEnabled = NO;
    [_field addSubview:_fieldLabel];

    _separator = [UIView new];
    _separator.backgroundColor = _dark ? [UIColor colorWithWhite:1 alpha:0.18] : [UIColor colorWithWhite:0 alpha:0.15];
    [self.view addSubview:_separator];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.backgroundColor = [UIColor clearColor];
    _table.separatorColor = _dark ? [UIColor colorWithWhite:1 alpha:0.15] : [UIColor colorWithWhite:0 alpha:0.12];
    _table.rowHeight = RFExplorerRowHeight;
    _table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _table.dataSource = self;
    _table.delegate = self;
    [_table registerClass:[RFExplorerCell class] forCellReuseIdentifier:RFExplorerCellIdentifier];
    [self.view addSubview:_table];

    [self loadEntries];
    [self refreshPath];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGSize size = self.view.bounds.size;
    CGFloat inset = RFExplorerButtonMargin * 2 + RFExplorerButtonWidth;
    CGFloat line = 1 / [UIScreen mainScreen].scale;

    _upButton.frame = CGRectMake(RFExplorerButtonMargin, 0, RFExplorerButtonWidth, RFExplorerHeaderHeight);
    _closeButton.frame = CGRectMake(size.width - RFExplorerButtonMargin - RFExplorerButtonWidth, 0,
                                    RFExplorerButtonWidth, RFExplorerHeaderHeight);
    _field.frame = CGRectMake(inset, (RFExplorerHeaderHeight - RFExplorerFieldHeight) / 2,
                              size.width - 2 * inset, RFExplorerFieldHeight);
    _fieldLabel.frame = CGRectInset(_field.bounds, RFExplorerFieldPadding, 0);
    _separator.frame = CGRectMake(0, RFExplorerHeaderHeight, size.width, line);
    _table.frame = CGRectMake(0, RFExplorerHeaderHeight + line, size.width,
                              size.height - RFExplorerHeaderHeight - line);
}

- (void)loadEntries {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *names = [manager contentsOfDirectoryAtPath:_path error:nil];
    NSMutableArray *folders = [NSMutableArray array];
    NSMutableArray *images = [NSMutableArray array];

    for (NSString *name in names) {
        if ([name hasPrefix:@"."]) continue;

        BOOL directory = NO;
        NSString *full = [_path stringByAppendingPathComponent:name];
        if (![manager fileExistsAtPath:full isDirectory:&directory]) continue;

        if (directory) {
            [folders addObject:name];
        } else if ([RFExplorerImageExtensions() containsObject:name.pathExtension.lowercaseString]) {
            [images addObject:name];
        }
    }

    SEL compare = @selector(localizedCaseInsensitiveCompare:);
    _folderCount = folders.count;
    _entries = [[folders sortedArrayUsingSelector:compare]
                arrayByAddingObjectsFromArray:[images sortedArrayUsingSelector:compare]];
}

- (UIView *)emptyView {
    UILabel *label = [UILabel new];
    label.text = @"No folders or images";
    label.textColor = [UIColor grayColor];
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (void)refreshPath {
    _field.text = _path;
    _fieldLabel.text = _path;
    _upButton.enabled = ![_path isEqualToString:@"/"];
    _table.backgroundView = _entries.count ? nil : [self emptyView];
}

- (void)openPath:(NSString *)path {
    _path = [path copy];
    [self loadEntries];
    [self refreshPath];

    [UIView transitionWithView:_table
                      duration:0.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [_table reloadData];
        _table.contentOffset = CGPointMake(0, -_table.contentInset.top);
    } completion:nil];
}

- (BOOL)commitPath:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return NO;

    NSString *expanded = [trimmed stringByExpandingTildeInPath];
    if (![expanded hasPrefix:@"/"]) expanded = [_path stringByAppendingPathComponent:expanded];
    NSString *path = [expanded stringByStandardizingPath];

    BOOL directory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory]) return NO;

    if (directory) {
        [self openPath:path];
        return YES;
    }

    if (![RFExplorerImageExtensions() containsObject:path.pathExtension.lowercaseString]) return NO;

    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (!image) return NO;

    if (_handler) _handler(image);
    return YES;
}

- (void)flashInvalid {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    animation.fromValue = (__bridge id)[UIColor redColor].CGColor;
    animation.toValue = (__bridge id)_field.layer.borderColor;
    animation.duration = 0.6;
    [_field.layer addAnimation:animation forKey:@"invalid"];
}

- (void)goUp {
    [self.view endEditing:YES];
    [self openPath:[_path stringByDeletingLastPathComponent]];
}

- (void)closeTapped {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)textFieldDidBeginEditing:(UITextField *)field {
    field.textColor = [self textColor];
    _fieldLabel.hidden = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [field selectAll:nil];
    });
}

- (void)textFieldDidEndEditing:(UITextField *)field {
    field.textColor = [UIColor clearColor];
    field.text = _path;
    _fieldLabel.hidden = NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
    if ([self commitPath:field.text]) {
        [field resignFirstResponder];
    } else {
        [self flashInvalid];
    }
    return NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RFExplorerCell *cell = [tableView dequeueReusableCellWithIdentifier:RFExplorerCellIdentifier
                                                           forIndexPath:indexPath];
    NSString *name = _entries[indexPath.row];
    NSString *path = [_path stringByAppendingPathComponent:name];
    BOOL folder = (NSUInteger)indexPath.row < _folderCount;

    cell.path = path;
    cell.textLabel.text = name;
    cell.textLabel.textColor = [self textColor];
    cell.selectedBackgroundView.backgroundColor = _dark ? [UIColor colorWithWhite:1 alpha:0.15]
                                                        : [UIColor colorWithWhite:0 alpha:0.1];
    cell.accessoryType = folder ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    if (folder) {
        cell.imageView.image = nil;
        return cell;
    }

    NSCache *cache = _thumbnails;
    UIImage *cached = [cache objectForKey:path];
    cell.imageView.image = cached ?: RFExplorerPlaceholder();
    if (cached) return cell;

    dispatch_async(RFExplorerQueue(), ^{
        UIImage *thumbnail = RFExplorerThumbnail(path);
        if (!thumbnail) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            [cache setObject:thumbnail forKey:path];
            if ([cell.path isEqualToString:path]) cell.imageView.image = thumbnail;
        });
    });
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.view endEditing:YES];
    NSString *path = [_path stringByAppendingPathComponent:_entries[indexPath.row]];

    if ((NSUInteger)indexPath.row < _folderCount) {
        [self openPath:path];
        return;
    }

    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (!image) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }

    if (_handler) _handler(image);
}

@end
