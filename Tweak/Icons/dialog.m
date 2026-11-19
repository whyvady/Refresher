#import "dialog.h"
#import "corners.h"

static const CGFloat RFDialogWidth = 300;
static const CGFloat RFDialogMenuWidth = 260;
static const CGFloat RFDialogPadding = 20;
static const CGFloat RFDialogGap = 8;
static const CGFloat RFDialogFieldHeight = 36;
static const CGFloat RFDialogFieldInset = 10;
static const CGFloat RFDialogButtonHeight = 48;
static const CGFloat RFDialogCornerRadius = 16;
static const CGFloat RFDialogMinimumTop = 20;
static const CGFloat RFDialogFieldAnchor = 0.3;

@interface RFDialog () <UITextFieldDelegate, UIGestureRecognizerDelegate>
@end

@implementation RFDialog {
    BOOL _dark;
    BOOL _stacked;
    BOOL _dismissed;
    UIView *_card;
    UILabel *_titleLabel;
    UILabel *_messageLabel;
    UITextField *_field;
    NSMutableArray *_buttons;
    NSMutableArray *_separators;
    NSMutableArray *_styles;
    NSMutableArray *_handlers;
}

- (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                         dark:(BOOL)dark
                      stacked:(BOOL)stacked {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _dark = dark;
    _stacked = stacked;
    _buttons = [NSMutableArray array];
    _separators = [NSMutableArray array];
    _styles = [NSMutableArray array];
    _handlers = [NSMutableArray array];

    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(backgroundTapped)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];

    _card = [UIView new];
    _card.backgroundColor = dark ? [UIColor colorWithWhite:0.17 alpha:1] : [UIColor colorWithWhite:0.97 alpha:1];
    _card.clipsToBounds = YES;
    RFSetCorners(_card.layer, RFDialogCornerRadius);
    [self addSubview:_card];

    _titleLabel = [self labelWithText:title font:[UIFont boldSystemFontOfSize:17] color:[self primaryColor]];
    _messageLabel = [self labelWithText:message font:[UIFont systemFontOfSize:13] color:[self secondaryColor]];

    return self;
}

- (UIColor *)primaryColor {
    return _dark ? [UIColor whiteColor] : [UIColor blackColor];
}

- (UIColor *)secondaryColor {
    return _dark ? [UIColor colorWithWhite:1 alpha:0.6] : [UIColor colorWithWhite:0 alpha:0.55];
}

- (UIColor *)accentColor {
    return _dark ? [UIColor colorWithRed:0.04 green:0.52 blue:1 alpha:1]
                 : [UIColor colorWithRed:0 green:0.48 blue:1 alpha:1];
}

- (UIColor *)lineColor {
    return _dark ? [UIColor colorWithWhite:1 alpha:0.18] : [UIColor colorWithWhite:0 alpha:0.15];
}

- (UIColor *)highlightColor {
    return _dark ? [UIColor colorWithWhite:1 alpha:0.12] : [UIColor colorWithWhite:0 alpha:0.08];
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    [_card addSubview:label];
    return label;
}

- (UITextField *)addTextFieldWithText:(NSString *)text placeholder:(NSString *)placeholder {
    if (_field) return _field;

    UITextField *field = [UITextField new];
    field.delegate = self;
    field.font = [UIFont systemFontOfSize:15];
    field.textColor = [self primaryColor];
    field.text = text;
    field.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:placeholder ?: @""
            attributes:@{NSForegroundColorAttributeName: [self secondaryColor]}];
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.returnKeyType = UIReturnKeyDone;
    field.keyboardAppearance = _dark ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    field.backgroundColor = _dark ? [UIColor colorWithWhite:1 alpha:0.1] : [UIColor colorWithWhite:0 alpha:0.06];
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, RFDialogFieldInset, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    RFSetCorners(field.layer, 8);
    [field addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];
    [_card addSubview:field];

    _field = field;
    [self updateEnabled];
    return field;
}

- (UIButton *)addActionWithTitle:(NSString *)title style:(RFDialogStyle)style handler:(void (^)(void))handler {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = (NSInteger)_buttons.count;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:style == RFDialogStyleDestructive ? [UIColor colorWithRed:1 green:0.27 blue:0.23 alpha:1]
                                                            : [self accentColor]
                 forState:UIControlStateNormal];
    [button setTitleColor:[self secondaryColor] forState:UIControlStateDisabled];
    button.titleLabel.font = style == RFDialogStyleProminent ? [UIFont boldSystemFontOfSize:17]
                                                              : [UIFont systemFontOfSize:17];
    [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(buttonDown:)
     forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button addTarget:self action:@selector(buttonUp:)
     forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                      UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [_card addSubview:button];

    UIView *separator = [UIView new];
    separator.backgroundColor = [self lineColor];
    separator.userInteractionEnabled = NO;
    [_card addSubview:separator];

    [_buttons addObject:button];
    [_separators addObject:separator];
    [_styles addObject:@(style)];
    [_handlers addObject:[handler copy] ?: (id)[NSNull null]];

    [self updateEnabled];
    return button;
}

- (void)updateEnabled {
    if (!_field) return;

    NSString *trimmed = [_field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSUInteger index = 0; index < _buttons.count; index++) {
        if ([_styles[index] integerValue] != RFDialogStyleProminent) continue;
        ((UIButton *)_buttons[index]).enabled = trimmed.length > 0;
    }
}

- (void)textChanged {
    [self updateEnabled];
}

- (void)buttonDown:(UIButton *)button {
    button.backgroundColor = [self highlightColor];
}

- (void)buttonUp:(UIButton *)button {
    button.backgroundColor = [UIColor clearColor];
}

- (void)buttonTapped:(UIButton *)button {
    if (_dismissed) return;

    id handler = _handlers[button.tag];
    [self dismiss];
    if (handler != [NSNull null]) ((void (^)(void))handler)();
}

- (void)backgroundTapped {
    [self endEditing:YES];
    if (_dismissesOnBackgroundTap) [self dismiss];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    return touch.view == self;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
    [field resignFirstResponder];
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)field {
    dispatch_async(dispatch_get_main_queue(), ^{
        [field selectAll:nil];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = _stacked ? RFDialogMenuWidth : RFDialogWidth;
    CGFloat inner = width - 2 * RFDialogPadding;
    CGFloat y = RFDialogPadding;

    if (_titleLabel.text.length) {
        CGFloat height = ceil([_titleLabel sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
        _titleLabel.frame = CGRectMake(RFDialogPadding, y, inner, height);
        y = CGRectGetMaxY(_titleLabel.frame) + RFDialogGap;
    }

    if (_messageLabel.text.length) {
        CGFloat height = ceil([_messageLabel sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)].height);
        _messageLabel.frame = CGRectMake(RFDialogPadding, y, inner, height);
        y = CGRectGetMaxY(_messageLabel.frame) + RFDialogGap;
    }

    if (_field) {
        _field.frame = CGRectMake(RFDialogPadding, y, inner, RFDialogFieldHeight);
        y = CGRectGetMaxY(_field.frame) + RFDialogGap;
    }

    y += RFDialogPadding - RFDialogGap;

    CGFloat line = 1 / [UIScreen mainScreen].scale;
    NSUInteger count = _buttons.count;

    for (NSUInteger index = 0; index < count; index++) {
        UIButton *button = _buttons[index];
        UIView *separator = _separators[index];

        if (_stacked) {
            button.frame = CGRectMake(0, y + index * RFDialogButtonHeight, width, RFDialogButtonHeight);
            separator.frame = CGRectMake(0, CGRectGetMinY(button.frame), width, line);
        } else {
            CGFloat part = width / count;
            button.frame = CGRectMake(index * part, y, part, RFDialogButtonHeight);
            separator.frame = index == 0 ? CGRectMake(0, y, width, line)
                                         : CGRectMake(index * part, y, line, RFDialogButtonHeight);
        }
    }

    CGFloat rows = _stacked ? count : (count ? 1 : 0);
    CGFloat height = y + rows * RFDialogButtonHeight;
    CGFloat anchor = _field ? self.bounds.size.height * RFDialogFieldAnchor : self.bounds.size.height / 2;
    CGFloat centerY = MAX(anchor, RFDialogMinimumTop + height / 2);

    _card.bounds = CGRectMake(0, 0, width, height);
    _card.center = CGPointMake(round(self.bounds.size.width / 2), round(centerY));
}

- (void)showInView:(UIView *)view {
    self.frame = view.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.alpha = 0;
    [view addSubview:self];
    [self layoutIfNeeded];

    _card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView animateWithDuration:0.18 animations:^{
        self.alpha = 1;
        _card.transform = CGAffineTransformIdentity;
    }];

    if (_field) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_field becomeFirstResponder];
        });
    }
}

- (void)dismiss {
    if (_dismissed) return;
    _dismissed = YES;

    [self endEditing:YES];
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
