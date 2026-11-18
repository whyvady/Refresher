#import "picker-controller.h"
#import "assets.h"

static NSString *const RFPickerCellIdentifier = @"RFPickerCell";
static const CGFloat RFPickerHeaderHeight = 44;
static const CGFloat RFPickerGridHeight = 136;
static const CGFloat RFPickerMinimumWidth = 360;
static const CGFloat RFPickerMinimumGap = 8;
static const CGFloat RFPickerMargin = 16;
static const CGFloat RFPickerTopLimit = 20;

static UIWindow *RFPickerWindow;

static BOOL RFPickerDark(void) {
    return [RFIconTheme() isEqualToString:@"Dark"];
}

static NSString *RFPickerCaption(NSString *name) {
    return [[name stringByReplacingOccurrencesOfString:@"-" withString:@" "] capitalizedString];
}

@interface RFPickerCell : UICollectionViewCell
- (void)configureWithName:(NSString *)name selected:(BOOL)selected;
@end

@implementation RFPickerCell {
    UIImageView *_iconView;
    UILabel *_captionLabel;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.contentView.layer.cornerRadius = 12;

    _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 8, 60, 60)];
    _iconView.layer.cornerRadius = 13.5;
    _iconView.layer.masksToBounds = YES;
    _iconView.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.25];
    [self.contentView addSubview:_iconView];

    _captionLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 72, 76, 28)];
    _captionLabel.font = [UIFont systemFontOfSize:11];
    _captionLabel.textAlignment = NSTextAlignmentCenter;
    _captionLabel.numberOfLines = 2;
    [self.contentView addSubview:_captionLabel];

    return self;
}

- (void)configureWithName:(NSString *)name selected:(BOOL)selected {
    _iconView.image = name ? RFIconImage(nil, name) : nil;
    _captionLabel.text = name ? RFPickerCaption(name) : @"Default";
    _captionLabel.textColor = RFPickerDark() ? [UIColor whiteColor] : [UIColor blackColor];
    self.contentView.backgroundColor = selected
        ? [UIColor colorWithRed:0 green:0.48 blue:1 alpha:0.25]
        : [UIColor clearColor];
}

@end

@interface RFPickerController () <UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate>
@end

@implementation RFPickerController {
    NSArray *_names;
    NSString *_selected;
    NSString *_heading;
    CGRect (^_anchor)(void);
    void (^_completion)(NSString *);
    BOOL _scrolled;
    UIView *_card;
    UILabel *_titleLabel;
    UIButton *_closeButton;
    UICollectionView *_grid;
}

+ (void)presentWithTitle:(NSString *)title
                selected:(NSString *)selected
                  anchor:(CGRect (^)(void))anchor
              completion:(void (^)(NSString *name))completion {
    if (RFPickerWindow) return;

    RFPickerController *controller = [[self alloc] initWithTitle:title
                                                        selected:selected
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
                       anchor:(CGRect (^)(void))anchor
                   completion:(void (^)(NSString *name))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;

    _heading = [title copy];
    _names = RFIconNames();
    _selected = [selected copy];
    _anchor = [anchor copy];
    _completion = [completion copy];

    return self;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    BOOL dark = RFPickerDark();

    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];

    _card = [UIView new];
    _card.layer.cornerRadius = 20;
    _card.clipsToBounds = YES;
    _card.backgroundColor = dark ? [UIColor colorWithWhite:0.11 alpha:0.96] : [UIColor colorWithWhite:1 alpha:0.96];
    [self.view addSubview:_card];

    _titleLabel = [UILabel new];
    _titleLabel.text = _heading;
    _titleLabel.font = [UIFont boldSystemFontOfSize:17];
    _titleLabel.textColor = dark ? [UIColor whiteColor] : [UIColor blackColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [_card addSubview:_titleLabel];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_closeButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_closeButton];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(80, 104);
    layout.minimumInteritemSpacing = 8;
    layout.minimumLineSpacing = 8;
    layout.sectionInset = UIEdgeInsetsMake(12, 16, 20, 16);

    _grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _grid.backgroundColor = [UIColor clearColor];
    _grid.showsHorizontalScrollIndicator = NO;
    _grid.alwaysBounceHorizontal = YES;
    _grid.dataSource = self;
    _grid.delegate = self;
    [_grid registerClass:[RFPickerCell class] forCellWithReuseIdentifier:RFPickerCellIdentifier];
    [_card addSubview:_grid];
}

- (CGRect)dockRect {
    CGSize screen = self.view.bounds.size;
    CGRect dock = _anchor ? _anchor() : CGRectZero;
    if (CGRectIsNull(dock) || CGRectIsEmpty(dock)) {
        dock = CGRectMake(RFPickerMargin, screen.height - 140, screen.width - 2 * RFPickerMargin, 100);
    }
    return dock;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGSize screen = self.view.bounds.size;
    CGRect dock = [self dockRect];

    CGFloat gap = MAX(screen.height - CGRectGetMaxY(dock), RFPickerMinimumGap);
    CGFloat width = MIN(MAX(dock.size.width, RFPickerMinimumWidth), screen.width - 2 * RFPickerMargin);
    CGFloat height = RFPickerHeaderHeight + RFPickerGridHeight;
    CGFloat x = MIN(MAX(CGRectGetMidX(dock) - width / 2, RFPickerMargin), screen.width - RFPickerMargin - width);
    CGFloat y = MAX(CGRectGetMinY(dock) - gap - height, RFPickerTopLimit);

    _card.frame = CGRectMake(floor(x), floor(y), floor(width), height);
    _titleLabel.frame = CGRectMake(80, 0, floor(width) - 160, RFPickerHeaderHeight);
    _closeButton.frame = CGRectMake(8, 0, 72, RFPickerHeaderHeight);
    _grid.frame = CGRectMake(0, RFPickerHeaderHeight, floor(width), RFPickerGridHeight);

    [self scrollToSelectedOnce];
}

- (void)scrollToSelectedOnce {
    if (_scrolled) return;
    _scrolled = YES;

    NSUInteger index = _selected.length ? [_names indexOfObject:_selected] : NSNotFound;
    if (index == NSNotFound) return;

    [_grid layoutIfNeeded];
    [_grid scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:index + 1 inSection:0]
                  atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
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

- (NSString *)nameAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.item == 0 ? nil : _names[indexPath.item - 1];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _names.count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RFPickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:RFPickerCellIdentifier
                                                                   forIndexPath:indexPath];
    NSString *name = [self nameAtIndexPath:indexPath];
    BOOL selected = name ? [name isEqualToString:_selected] : !_selected.length;
    [cell configureWithName:name selected:selected];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (_completion) _completion([self nameAtIndexPath:indexPath]);
    [self close];
}

@end
