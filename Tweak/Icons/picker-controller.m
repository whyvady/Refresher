#import "picker-controller.h"
#import "assets.h"

static NSString *const RFPickerCellIdentifier = @"RFPickerCell";

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
    _iconView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
    [self.contentView addSubview:_iconView];

    _captionLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 72, 76, 28)];
    _captionLabel.font = [UIFont systemFontOfSize:11];
    _captionLabel.textColor = [UIColor blackColor];
    _captionLabel.textAlignment = NSTextAlignmentCenter;
    _captionLabel.numberOfLines = 2;
    [self.contentView addSubview:_captionLabel];

    return self;
}

- (void)configureWithName:(NSString *)name selected:(BOOL)selected {
    _iconView.image = name ? RFIconImage(nil, name) : nil;
    _captionLabel.text = name ? RFPickerCaption(name) : @"Default";
    self.contentView.backgroundColor = selected
        ? [UIColor colorWithRed:0 green:0.48 blue:1 alpha:0.18]
        : [UIColor clearColor];
}

@end

@interface RFPickerController () <UICollectionViewDataSource, UICollectionViewDelegate>
@end

@implementation RFPickerController {
    NSArray *_names;
    NSString *_selected;
    void (^_completion)(NSString *);
}

- (instancetype)initWithTitle:(NSString *)title
                     selected:(NSString *)selected
                   completion:(void (^)(NSString *name))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;

    self.title = title;
    self.preferredContentSize = CGSizeMake(420, 520);
    _names = RFIconNames();
    _selected = [selected copy];
    _completion = [completion copy];

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(80, 104);
    layout.minimumInteritemSpacing = 8;
    layout.minimumLineSpacing = 8;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);

    UICollectionView *grid = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    grid.backgroundColor = [UIColor whiteColor];
    grid.dataSource = self;
    grid.delegate = self;
    [grid registerClass:[RFPickerCell class] forCellWithReuseIdentifier:RFPickerCellIdentifier];
    [self.view addSubview:grid];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
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
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
