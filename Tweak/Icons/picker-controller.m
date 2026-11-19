#import "picker-controller.h"
#import "apps.h"
#import "app-options.h"
#import "assets.h"
#import "corners.h"
#import "dialog.h"
#import "explorer-controller.h"
#import "icon-shape.h"
typedef NS_ENUM(NSInteger, RFPickerItemKind) {
    RFPickerItemDefault,
    RFPickerItemFolder,
    RFPickerItemIcon
};
static NSString *const RFPickerCellIdentifier = @"RFPickerCell";
static const CGFloat RFPickerHeaderHeight = 44;
static const CGFloat RFPickerButtonWidth = 72;
static const CGFloat RFPickerMinimumWidth = 360;
static const CGFloat RFPickerMinimumHeight = 240;
static const CGFloat RFPickerMinimumGap = 8;
static const CGFloat RFPickerMargin = 16;
static const CGFloat RFPickerDockSideMargin = 31.75;
static const CGFloat RFPickerTopMultiplier = 2;
static const CGFloat RFPickerSheetWidth = 540;
static const CGFloat RFPickerSheetHeight = 620;
static const CGFloat RFPickerCellWidth = 80;
static const CGFloat RFPickerCellHeight = 104;
static const CGFloat RFPickerIconSide = 60;
static const CGFloat RFPickerBadgeSide = 22;
static const CGFloat RFPickerSpacing = 8;
static const CGFloat RFPickerSideInset = 12;
static const CGFloat RFPickerGridInsetTop = 12;
static const CGFloat RFPickerGridInsetBottom = 20;
static const CGFloat RFPickerMenuWidth = 200;
static const CGFloat RFPickerMenuRowHeight = 48;
static const CGFloat RFPickerMenuArrowHeight = 9;
static const CGFloat RFPickerMenuArrowWidth = 20;
static UIWindow *RFPickerWindow;
static BOOL RFPickerDark(void) {
    return [RFIconTheme() isEqualToString:@"Dark"];
}
static CGFloat RFPickerScale(void) {
    return [UIScreen mainScreen].scale;
}
static NSString *RFPickerTrimmed(NSString *text) {
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
static NSString *RFPickerOtherTheme(NSString *theme) {
    return [theme isEqualToString:@"Dark"] ? @"Light" : @"Dark";
}
static NSString *RFPickerNormalized(NSString *name) {
    if (!name.length || RFIsCustomIcon(name) || RFIconVariantTheme(name)) return name;
    return RFIconVariantName(name, RFIconTheme());
}
static NSString *RFPickerFolderTitle(NSString *theme) {
    return [NSString stringWithFormat:@"Apple (%@)", theme];
}
static NSString *RFPickerStockCaption(NSString *value) {
    return [[RFIconBaseName(value) stringByReplacingOccurrencesOfString:@"-" withString:@" "] capitalizedString];
}
static UIImage *RFPickerColorImage(UIColor *color) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [color setFill];
        UIRectFill(CGRectMake(0, 0, 1, 1));
    }];
}
static UIImage *RFPickerThumbnail(UIImage *source, CGFloat scale) {
    CGRect rect = CGRectMake(0, 0, RFPickerIconSide, RFPickerIconSide);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat new];
    format.scale = scale;
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rect.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [RFIconShapePath(rect) addClip];
        [source drawInRect:rect];
    }];
}
static UIImage *RFPickerPlaceholder(void) {
    static UIImage *placeholder;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGRect rect = CGRectMake(0, 0, RFPickerIconSide, RFPickerIconSide);
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat new];
        format.scale = RFPickerScale();
        format.opaque = NO;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rect.size format:format];
        placeholder = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [[UIColor colorWithWhite:0.5 alpha:0.25] setFill];
            [RFIconShapePath(rect) fill];
        }];
    });
    return placeholder;
}
@interface RFPickerItem : NSObject
@property (nonatomic, readonly) RFPickerItemKind kind;
@property (nonatomic, readonly, copy) NSString *value;
@property (nonatomic, readonly, copy) NSString *caption;
@property (nonatomic, readonly, copy) NSString *cover;
+ (instancetype)itemWithKind:(RFPickerItemKind)kind
                       value:(NSString *)value
                     caption:(NSString *)caption
                       cover:(NSString *)cover;
@end
@implementation RFPickerItem
+ (instancetype)itemWithKind:(RFPickerItemKind)kind
                       value:(NSString *)value
                     caption:(NSString *)caption
                       cover:(NSString *)cover {
    RFPickerItem *item = [self new];
    item->_kind = kind;
    item->_value = [value copy];
    item->_caption = [caption copy];
    item->_cover = [cover copy];
    return item;
}
@end
@interface RFPickerMenu : UIView
- (instancetype)initWithTitles:(NSArray *)titles dark:(BOOL)dark handler:(void (^)(NSInteger index))handler;
- (void)showInView:(UIView *)view anchor:(CGRect)anchor;
- (void)dismiss;
@end
@implementation RFPickerMenu {
    NSArray *_titles;
    BOOL _dark;
    void (^_handler)(NSInteger);
}
- (instancetype)initWithTitles:(NSArray *)titles dark:(BOOL)dark handler:(void (^)(NSInteger index))handler {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _titles = [titles copy];
    _dark = dark;
    _handler = [handler copy];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return self;
}
- (void)showInView:(UIView *)view anchor:(CGRect)anchor {
    self.frame = view.bounds;
    [view addSubview:self];
    CGFloat width = RFPickerMenuWidth;
    CGFloat bodyHeight = _titles.count * RFPickerMenuRowHeight;
    CGFloat x = MIN(MAX(CGRectGetMaxX(anchor) - width, 8), view.bounds.size.width - 8 - width);
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(x, CGRectGetMaxY(anchor), width,
                                                             bodyHeight + RFPickerMenuArrowHeight)];
    panel.layer.shadowColor = [UIColor blackColor].CGColor;
    panel.layer.shadowOpacity = 0.25;
    panel.layer.shadowRadius = 16;
    panel.layer.shadowOffset = CGSizeMake(0, 4);
    [self addSubview:panel];
    UIColor *fill = _dark ? [UIColor colorWithWhite:0.17 alpha:1] : [UIColor whiteColor];
    UIColor *text = _dark ? [UIColor whiteColor] : [UIColor blackColor];
    UIColor *line = _dark ? [UIColor colorWithWhite:1 alpha:0.15] : [UIColor colorWithWhite:0 alpha:0.15];
    UIColor *pressed = _dark ? [UIColor colorWithWhite:1 alpha:0.12] : [UIColor colorWithWhite:0 alpha:0.08];
    UIView *body = [[UIView alloc] initWithFrame:CGRectMake(0, RFPickerMenuArrowHeight, width, bodyHeight)];
    body.backgroundColor = fill;
    RFSetCorners(body.layer, 14);
    body.clipsToBounds = YES;
    [panel addSubview:body];
    CGFloat arrowX = MIN(MAX(CGRectGetMidX(anchor) - x, 24), width - 24);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(arrowX - RFPickerMenuArrowWidth / 2, RFPickerMenuArrowHeight + 1)];
    [path addLineToPoint:CGPointMake(arrowX, 0)];
    [path addLineToPoint:CGPointMake(arrowX + RFPickerMenuArrowWidth / 2, RFPickerMenuArrowHeight + 1)];
    [path closePath];
    CAShapeLayer *arrow = [CAShapeLayer layer];
    arrow.path = path.CGPath;
    arrow.fillColor = fill.CGColor;
    [panel.layer addSublayer:arrow];
    UIImage *pressedImage = RFPickerColorImage(pressed);
    CGFloat hairline = 1 / RFPickerScale();
    for (NSUInteger index = 0; index < _titles.count; index++) {
        CGFloat y = index * RFPickerMenuRowHeight;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0, y, width, RFPickerMenuRowHeight);
        button.tag = (NSInteger)index;
        button.titleLabel.font = [UIFont systemFontOfSize:17];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        [button setTitle:_titles[index] forState:UIControlStateNormal];
        [button setTitleColor:text forState:UIControlStateNormal];
        [button setBackgroundImage:pressedImage forState:UIControlStateHighlighted];
        [button addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [body addSubview:button];
        if (!index) continue;
        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(16, y, width - 16, hairline)];
        separator.backgroundColor = line;
        [body addSubview:separator];
    }
    panel.alpha = 0;
    [UIView animateWithDuration:0.15 animations:^{
        panel.alpha = 1;
    }];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self dismiss];
}
- (void)tapped:(UIButton *)button {
    void (^handler)(NSInteger) = _handler;
    [self removeFromSuperview];
    if (handler) handler(button.tag);
}
- (void)dismiss {
    [UIView animateWithDuration:0.12 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}
@end
@interface RFPickerCell : UICollectionViewCell
@property (nonatomic, copy) NSString *token;
- (void)setThumbnail:(UIImage *)image;
- (void)configureWithCaption:(NSString *)caption
                    selected:(BOOL)selected
                   selecting:(BOOL)selecting
                   deletable:(BOOL)deletable
                      marked:(BOOL)marked;
@end
@implementation RFPickerCell {
    UIImageView *_iconView;
    UILabel *_captionLabel;
    UILabel *_badge;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    RFSetCorners(self.contentView.layer, 12);
    _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 8, RFPickerIconSide, RFPickerIconSide)];
    [self.contentView addSubview:_iconView];
    _captionLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 72, 76, 28)];
    _captionLabel.font = [UIFont systemFontOfSize:11];
    _captionLabel.textAlignment = NSTextAlignmentCenter;
    _captionLabel.numberOfLines = 2;
    [self.contentView addSubview:_captionLabel];
    _badge = [[UILabel alloc] initWithFrame:CGRectMake(52, 2, RFPickerBadgeSide, RFPickerBadgeSide)];
    _badge.font = [UIFont boldSystemFontOfSize:13];
    _badge.textAlignment = NSTextAlignmentCenter;
    _badge.textColor = [UIColor whiteColor];
    _badge.layer.cornerRadius = RFPickerBadgeSide / 2;
    _badge.layer.borderWidth = 1.5;
    _badge.layer.borderColor = [UIColor whiteColor].CGColor;
    _badge.layer.masksToBounds = YES;
    _badge.hidden = YES;
    [self.contentView addSubview:_badge];
    return self;
}
- (void)prepareForReuse {
    [super prepareForReuse];
    self.token = nil;
}
- (void)setThumbnail:(UIImage *)image {
    _iconView.image = image ?: RFPickerPlaceholder();
}
- (void)configureWithCaption:(NSString *)caption
                    selected:(BOOL)selected
                   selecting:(BOOL)selecting
                   deletable:(BOOL)deletable
                      marked:(BOOL)marked {
    _captionLabel.text = caption;
    _captionLabel.textColor = RFPickerDark() ? [UIColor whiteColor] : [UIColor blackColor];
    self.contentView.backgroundColor = selected
        ? [UIColor colorWithRed:0 green:0.48 blue:1 alpha:0.25]
        : [UIColor clearColor];
    self.contentView.alpha = (selecting && !deletable) ? 0.35 : 1;
    _badge.hidden = !(selecting && deletable);
    _badge.text = marked ? @"\u2713" : nil;
    _badge.backgroundColor = marked
        ? [UIColor colorWithRed:0 green:0.48 blue:1 alpha:1]
        : [UIColor colorWithWhite:0 alpha:0.3];
}
@end
@interface RFPickerController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                                  UIGestureRecognizerDelegate, UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate, UIDocumentPickerDelegate>
@end
@implementation RFPickerController {
    NSArray *_items;
    NSArray *_rootItems;
    NSDictionary *_folders;
    NSString *_folder;
    NSArray *_customs;
    NSArray *_stock;
    NSArray *_own;
    NSString *_selected;
    NSString *_heading;
    UIImage *_defaultIcon;
    UIImage *_defaultThumbnail;
    NSCache *_thumbnails;
    CGRect (^_anchor)(void);
    void (^_completion)(NSString *);
    CGFloat _gridInset;
    CGFloat _gridSpacing;
    BOOL _scrolled;
    BOOL _selecting;
    NSMutableSet *_marked;
    UIImage *_pendingImage;
    RFDialog *_dialog;
    RFPickerMenu *_menu;
    UIView *_card;
    UILabel *_titleLabel;
    UIButton *_closeButton;
    UIButton *_selectButton;
    UIButton *_addButton;
    UIButton *_deleteButton;
    UICollectionView *_grid;
}
+ (void)presentWithTitle:(NSString *)title
                selected:(NSString *)selected
             defaultIcon:(UIImage *)defaultIcon
                ownNames:(NSArray *)ownNames
                  anchor:(CGRect (^)(void))anchor
              completion:(void (^)(NSString *name))completion {
    if (RFPickerWindow) return;
    RFPickerController *controller = [[self alloc] initWithTitle:title
                                                        selected:selected
                                                     defaultIcon:defaultIcon
                                                        ownNames:ownNames
                                                          anchor:anchor
                                                      completion:completion];
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.windowLevel = UIWindowLevelAlert + 1;
    window.rootViewController = controller;
    window.alpha = 0;
    window.hidden = NO;
    RFPickerWindow = window;
    [UIView animateWithDuration:0.2 animations:^{
        window.alpha = 1;
    }];
}
- (instancetype)initWithTitle:(NSString *)title
                     selected:(NSString *)selected
                  defaultIcon:(UIImage *)defaultIcon
                     ownNames:(NSArray *)ownNames
                       anchor:(CGRect (^)(void))anchor
                   completion:(void (^)(NSString *name))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _heading = [title copy];
    _customs = RFCustomIconNames();
    _stock = RFIconNames();
    _own = ownNames ?: @[];
    _selected = [RFPickerNormalized(selected) copy];
    _defaultIcon = defaultIcon;
    _defaultThumbnail = defaultIcon ? RFPickerThumbnail(defaultIcon, RFPickerScale()) : nil;
    _thumbnails = [NSCache new];
    _thumbnails.countLimit = 400;
    _anchor = [anchor copy];
    _completion = [completion copy];
    _marked = [NSMutableSet set];
    _gridInset = RFPickerSideInset;
    _gridSpacing = RFPickerSpacing;
    [self rebuildItems];
    return self;
}
- (NSArray *)stockItemsForTheme:(NSString *)theme {
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *name in _own) {
        NSString *value = RFIconVariantName(name, theme);
        if (!RFIconImage(nil, value)) continue;
        [items addObject:[RFPickerItem itemWithKind:RFPickerItemIcon
                                              value:value
                                            caption:RFPickerStockCaption(value)
                                              cover:value]];
    }
    for (NSString *name in _stock) {
        if ([_own containsObject:name]) continue;
        NSString *value = RFIconVariantName(name, theme);
        [items addObject:[RFPickerItem itemWithKind:RFPickerItemIcon
                                              value:value
                                            caption:RFPickerStockCaption(value)
                                              cover:value]];
    }
    return items;
}
- (void)rebuildItems {
    NSString *current = RFIconTheme();
    NSMutableArray *root = [NSMutableArray array];
    NSMutableDictionary *folders = [NSMutableDictionary dictionary];
    NSString *coverName = nil;
    for (NSString *name in _stock) {
        if (![_own containsObject:name]) {
            coverName = name;
            break;
        }
    }
    [root addObject:[RFPickerItem itemWithKind:RFPickerItemDefault value:nil caption:@"Default" cover:nil]];
    for (NSString *theme in @[current, RFPickerOtherTheme(current)]) {
        NSArray *icons = [self stockItemsForTheme:theme];
        if (!icons.count) continue;
        NSString *cover = coverName ? RFIconVariantName(coverName, theme) : ((RFPickerItem *)icons.firstObject).value;
        folders[theme] = icons;
        [root addObject:[RFPickerItem itemWithKind:RFPickerItemFolder
                                             value:theme
                                           caption:RFPickerFolderTitle(theme)
                                             cover:cover]];
    }
    for (NSString *name in _customs) {
        [root addObject:[RFPickerItem itemWithKind:RFPickerItemIcon
                                             value:name
                                           caption:RFCustomIconTitle(name)
                                             cover:name]];
    }
    _rootItems = root;
    _folders = folders;
    _items = _folder ? (folders[_folder] ?: root) : root;
}
- (void)reloadCustoms {
    _customs = RFCustomIconNames();
    [self rebuildItems];
    [self updateHeader];
    [_grid reloadData];
}
- (BOOL)isSelectedItem:(RFPickerItem *)item {
    if (item.kind == RFPickerItemDefault) return !_selected.length;
    if (item.kind == RFPickerItemIcon) return [item.value isEqualToString:_selected];
    if (!_selected.length || RFIsCustomIcon(_selected)) return NO;
    return [RFIconVariantTheme(_selected) isEqualToString:item.value];
}
- (NSIndexPath *)indexPathForValue:(NSString *)value {
    if (!value.length) return nil;
    for (NSUInteger index = 0; index < _items.count; index++) {
        RFPickerItem *item = _items[index];
        if (item.kind == RFPickerItemIcon && [item.value isEqualToString:value]) {
            return [NSIndexPath indexPathForItem:(NSInteger)index inSection:0];
        }
    }
    return nil;
}
- (BOOL)shouldAutorotate {
    return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [_menu dismiss];
}
- (UIButton *)headerButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:button];
    return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    BOOL dark = RFPickerDark();
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    _card = [UIView new];
    RFSetCorners(_card.layer, 20);
    _card.clipsToBounds = YES;
    _card.backgroundColor = dark ? [UIColor colorWithWhite:0.11 alpha:0.96] : [UIColor colorWithWhite:1 alpha:0.96];
    [self.view addSubview:_card];
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont boldSystemFontOfSize:17];
    _titleLabel.textColor = dark ? [UIColor whiteColor] : [UIColor blackColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.5;
    [_card addSubview:_titleLabel];
    _closeButton = [self headerButtonWithTitle:@"Close" action:@selector(closeTapped)];
    _selectButton = [self headerButtonWithTitle:@"Select" action:@selector(selectTapped)];
    _addButton = [self headerButtonWithTitle:@"Add" action:@selector(add)];
    _deleteButton = [self headerButtonWithTitle:@"Delete" action:@selector(confirmDelete)];
    _deleteButton.tintColor = [UIColor redColor];
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.itemSize = CGSizeMake(RFPickerCellWidth, RFPickerCellHeight);
    layout.minimumInteritemSpacing = _gridSpacing;
    layout.minimumLineSpacing = RFPickerSpacing;
    _grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _grid.backgroundColor = [UIColor clearColor];
    _grid.alwaysBounceVertical = YES;
    _grid.dataSource = self;
    _grid.delegate = self;
    [_grid registerClass:[RFPickerCell class] forCellWithReuseIdentifier:RFPickerCellIdentifier];
    [_card addSubview:_grid];
    UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                       action:@selector(handleHold:)];
    [_grid addGestureRecognizer:hold];
    [self updateHeader];
}
- (void)updateHeader {
    [UIView performWithoutAnimation:^{
        if (_selecting) {
            _titleLabel.text = _marked.count
                ? [NSString stringWithFormat:@"%lu Selected", (unsigned long)_marked.count]
                : @"Select Icons";
        } else if (_folder) {
            _titleLabel.text = RFPickerFolderTitle(_folder);
        } else {
            _titleLabel.text = _heading;
        }
        NSString *leading = _selecting ? @"Done" : (_folder ? @"Back" : @"Close");
        [_closeButton setTitle:leading forState:UIControlStateNormal];
        [_closeButton layoutIfNeeded];
        BOOL tools = !_folder && !_selecting;
        _selectButton.hidden = !tools;
        _addButton.hidden = !tools;
        _deleteButton.hidden = !_selecting;
        _deleteButton.enabled = _marked.count > 0;
        _selectButton.enabled = _customs.count > 0;
    }];
}
- (void)setSelectionMode:(BOOL)selecting {
    _selecting = selecting;
    [_marked removeAllObjects];
    [self updateHeader];
    [_grid reloadData];
}
- (void)showItemsAnimated:(BOOL)animated scrollToSelected:(BOOL)scroll {
    _items = _folder ? _folders[_folder] : _rootItems;
    [self updateHeader];
    void (^reload)(void) = ^{
        [_grid reloadData];
        [_grid layoutIfNeeded];
        NSIndexPath *indexPath = scroll ? [self indexPathForValue:_selected] : nil;
        if (indexPath) {
            [_grid scrollToItemAtIndexPath:indexPath
                          atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                                  animated:NO];
        } else {
            [_grid setContentOffset:CGPointZero animated:NO];
        }
    };
    if (!animated) {
        reload();
        return;
    }
    [UIView transitionWithView:_grid
                      duration:0.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:reload
                    completion:nil];
}
- (void)openFolder:(NSString *)theme {
    if (!_folders[theme]) return;
    _folder = [theme copy];
    [self showItemsAnimated:YES scrollToSelected:YES];
}
- (void)leaveFolder {
    _folder = nil;
    [self showItemsAnimated:YES scrollToSelected:NO];
}
- (CGRect)dockRect {
    CGSize screen = self.view.bounds.size;
    CGRect dock = _anchor ? _anchor() : CGRectZero;
    if (CGRectIsNull(dock) || CGRectIsEmpty(dock)) {
        dock = CGRectMake(RFPickerMargin, screen.height - 140, screen.width - 2 * RFPickerMargin, 100);
    }
    return dock;
}
- (void)updateGridLayout {
    CGFloat width = _grid.bounds.size.width;
    CGFloat available = width - 2 * RFPickerSideInset;
    NSInteger columns = MAX(1, (NSInteger)floor((available + RFPickerSpacing) / (RFPickerCellWidth + RFPickerSpacing)));
    CGFloat spacing = columns > 1
        ? floor((available - columns * RFPickerCellWidth) / (columns - 1))
        : RFPickerSpacing;
    CGFloat used = columns * RFPickerCellWidth + (columns - 1) * spacing;
    CGFloat inset = MAX(floor((width - used) / 2), 0);
    if (inset == _gridInset && spacing == _gridSpacing) return;
    _gridInset = inset;
    _gridSpacing = spacing;
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)_grid.collectionViewLayout;
    layout.minimumInteritemSpacing = spacing;
    [layout invalidateLayout];
    [_grid reloadData];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize screen = self.view.bounds.size;
    CGRect dock = [self dockRect];
    CGFloat gap = MAX(screen.height - CGRectGetMaxY(dock), RFPickerMinimumGap);
    CGFloat top = floor(gap * RFPickerTopMultiplier);
    CGFloat wide = MAX(MAX(screen.width - 2 * RFPickerDockSideMargin, dock.size.width), RFPickerMinimumWidth);
    CGFloat width = floor(MIN(wide, screen.width - 2 * RFPickerMargin));
    CGFloat bottom = MAX(CGRectGetMinY(dock) - gap, top + RFPickerMinimumHeight);
    CGFloat height = floor(bottom - top);
    CGFloat x = floor((screen.width - width) / 2);
    CGFloat side = RFPickerButtonWidth + 8;
    _card.frame = CGRectMake(x, top, width, height);
    _titleLabel.frame = CGRectMake(side + RFPickerButtonWidth, 0, width - 2 * (side + RFPickerButtonWidth),
                                   RFPickerHeaderHeight);
    _closeButton.frame = CGRectMake(8, 0, RFPickerButtonWidth, RFPickerHeaderHeight);
    _addButton.frame = CGRectMake(width - side, 0, RFPickerButtonWidth, RFPickerHeaderHeight);
    _deleteButton.frame = _addButton.frame;
    _selectButton.frame = CGRectMake(width - side - RFPickerButtonWidth, 0, RFPickerButtonWidth,
                                     RFPickerHeaderHeight);
    _grid.frame = CGRectMake(0, RFPickerHeaderHeight, width, height - RFPickerHeaderHeight);
    [self updateGridLayout];
    [self scrollToSelectedOnce];
}
- (void)scrollToSelectedOnce {
    if (_scrolled) return;
    _scrolled = YES;
    NSIndexPath *indexPath = [self indexPathForValue:_selected];
    if (!indexPath) return;
    [_grid layoutIfNeeded];
    [_grid scrollToItemAtIndexPath:indexPath
                  atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                          animated:NO];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    return touch.view == self.view;
}
- (void)close {
    UIWindow *window = RFPickerWindow;
    [UIView animateWithDuration:0.2 animations:^{
        window.alpha = 0;
    } completion:^(BOOL finished) {
        window.hidden = YES;
        if (RFPickerWindow == window) RFPickerWindow = nil;
    }];
}
- (void)closeTapped {
    if (_selecting) {
        [self setSelectionMode:NO];
    } else if (_folder) {
        [self leaveFolder];
    } else {
        [self close];
    }
}
- (void)selectTapped {
    [self setSelectionMode:YES];
}
- (void)showDialog:(RFDialog *)dialog {
    _dialog = dialog;
    [dialog showInView:self.view];
}
- (void)confirmDelete {
    NSUInteger count = _marked.count;
    if (!count) return;
    NSString *title = count == 1
        ? @"Delete Icon?"
        : [NSString stringWithFormat:@"Delete %lu Icons?", (unsigned long)count];
    RFDialog *dialog = [[RFDialog alloc] initWithTitle:title
                                               message:@"Apps using them will return to their default icons."
                                                  dark:RFPickerDark()
                                               stacked:NO];
    __weak typeof(self) weakSelf = self;
    [dialog addActionWithTitle:@"Cancel" style:RFDialogStyleProminent handler:nil];
    [dialog addActionWithTitle:@"Delete" style:RFDialogStyleDestructive handler:^{
        [weakSelf deleteMarked];
    }];
    [self showDialog:dialog];
}
- (void)deleteMarked {
    NSArray *names = _marked.allObjects;
    for (NSString *name in names) RFRemoveCustomIcon(name);
    RFForgetAlternativeIcons(names);
    RFAppsRefresh(nil);
    if (_selected.length && [names containsObject:_selected]) _selected = nil;
    _customs = RFCustomIconNames();
    [self rebuildItems];
    [self setSelectionMode:NO];
}
- (void)presentSheet:(UIViewController *)controller {
    controller.modalPresentationStyle = UIModalPresentationFormSheet;
    controller.preferredContentSize = CGSizeMake(RFPickerSheetWidth, RFPickerSheetHeight);
    [self presentViewController:controller animated:YES completion:nil];
}
- (void)add {
    if (_menu.superview) return;
    __weak typeof(self) weakSelf = self;
    _menu = [[RFPickerMenu alloc] initWithTitles:@[@"Photos", @"Files", @"Explorer"]
                                            dark:RFPickerDark()
                                         handler:^(NSInteger index) {
        [weakSelf presentSourceAtIndex:index];
    }];
    [_menu showInView:self.view anchor:[_card convertRect:_addButton.frame toView:self.view]];
}
- (void)presentSourceAtIndex:(NSInteger)index {
    if (index == 0) {
        [self presentPhotos];
    } else if (index == 1) {
        [self presentFiles];
    } else {
        [self presentExplorer];
    }
}
- (void)presentPhotos {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentSheet:picker];
}
- (void)presentFiles {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"]
                                                               inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    [self presentSheet:picker];
}
- (void)presentExplorer {
    __weak typeof(self) weakSelf = self;
    RFExplorerController *explorer = [[RFExplorerController alloc] initWithHandler:^(UIImage *image) {
        [weakSelf promptNameForImage:image];
    }];
    [self presentSheet:explorer];
}
- (void)presentNameDialogWithTitle:(NSString *)title
                              text:(NSString *)text
                            cancel:(void (^)(void))cancel
                              save:(void (^)(NSString *name))save {
    RFDialog *dialog = [[RFDialog alloc] initWithTitle:title message:nil dark:RFPickerDark() stacked:NO];
    UITextField *field = [dialog addTextFieldWithText:text placeholder:@"Icon name"];
    [dialog addActionWithTitle:@"Cancel" style:RFDialogStyleNormal handler:cancel];
    [dialog addActionWithTitle:@"Save" style:RFDialogStyleProminent handler:^{
        NSString *trimmed = RFPickerTrimmed(field.text);
        if (trimmed.length) save(trimmed);
    }];
    [self showDialog:dialog];
}
- (void)promptNameForImage:(UIImage *)image {
    _pendingImage = image;
    UIViewController *presented = self.presentedViewController;
    if (!presented) {
        [self presentNamePrompt];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [presented dismissViewControllerAnimated:YES completion:^{
        [weakSelf presentNamePrompt];
    }];
}
- (void)presentNamePrompt {
    if (!_pendingImage) return;
    __weak typeof(self) weakSelf = self;
    [self presentNameDialogWithTitle:@"Name Your Icon"
                                text:nil
                              cancel:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) strongSelf->_pendingImage = nil;
    }
                                save:^(NSString *title) {
        [weakSelf saveWithTitle:title];
    }];
}
- (void)saveWithTitle:(NSString *)title {
    UIImage *image = _pendingImage;
    _pendingImage = nil;
    if (!image || !title.length) return;
    NSString *name = RFSaveCustomIcon(image, title);
    if (!name) return;
    if (_completion) _completion(name);
    [self showSavedIcon:name];
}
- (void)showSavedIcon:(NSString *)name {
    _selected = name;
    [self reloadCustoms];
    NSIndexPath *indexPath = [self indexPathForValue:name];
    if (!indexPath) return;
    [_grid layoutIfNeeded];
    [_grid scrollToItemAtIndexPath:indexPath
                  atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                          animated:YES];
}
- (void)handleHold:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan || _selecting || _dialog.superview) return;
    NSIndexPath *indexPath = [_grid indexPathForItemAtPoint:[recognizer locationInView:_grid]];
    if (!indexPath) return;
    RFPickerItem *item = _items[indexPath.item];
    NSString *name = item.value;
    if (item.kind != RFPickerItemIcon || !RFIsCustomIcon(name)) return;
    __weak typeof(self) weakSelf = self;
    [self presentNameDialogWithTitle:@"Rename Icon"
                                text:RFCustomIconTitle(name)
                              cancel:nil
                                save:^(NSString *title) {
        RFRenameCustomIcon(name, title);
        [weakSelf reloadCustoms];
    }];
}
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        [self promptNameForImage:image];
    } else {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    UIImage *image = url ? [UIImage imageWithContentsOfFile:url.path] : nil;
    if (image) [self promptNameForImage:image];
}
- (void)loadThumbnailForItem:(RFPickerItem *)item intoCell:(RFPickerCell *)cell {
    NSString *key = item.cover ?: @"";
    cell.token = key;
    if (!key.length) {
        [cell setThumbnail:_defaultThumbnail];
        return;
    }
    UIImage *cached = [_thumbnails objectForKey:key];
    if (cached) {
        [cell setThumbnail:cached];
        return;
    }
    [cell setThumbnail:nil];
    UIImage *source = RFIconImage(nil, key);
    if (!source) return;
    NSCache *cache = _thumbnails;
    CGFloat scale = RFPickerScale();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *thumbnail = RFPickerThumbnail(source, scale);
        dispatch_async(dispatch_get_main_queue(), ^{
            [cache setObject:thumbnail forKey:key];
            if ([cell.token isEqualToString:key]) [cell setThumbnail:thumbnail];
        });
    });
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (NSInteger)_items.count;
}
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)layout
        insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(RFPickerGridInsetTop, _gridInset, RFPickerGridInsetBottom, _gridInset);
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RFPickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:RFPickerCellIdentifier
                                                                   forIndexPath:indexPath];
    RFPickerItem *item = _items[indexPath.item];
    BOOL custom = item.kind == RFPickerItemIcon && RFIsCustomIcon(item.value);
    [cell configureWithCaption:item.caption
                      selected:[self isSelectedItem:item]
                     selecting:_selecting
                     deletable:custom
                        marked:custom && [_marked containsObject:item.value]];
    [self loadThumbnailForItem:item intoCell:cell];
    return cell;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    RFPickerItem *item = _items[indexPath.item];
    if (_selecting) {
        if (item.kind != RFPickerItemIcon || !RFIsCustomIcon(item.value)) return;
        if ([_marked containsObject:item.value]) {
            [_marked removeObject:item.value];
        } else {
            [_marked addObject:item.value];
        }
        [self updateHeader];
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];
        return;
    }
    if (item.kind == RFPickerItemFolder) {
        [self openFolder:item.value];
        return;
    }
    if (_completion) _completion(item.value);
    [self close];
}
@end
