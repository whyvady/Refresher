#import "clock-face.h"
#import <QuartzCore/QuartzCore.h>
#import "assets.h"
#import "icon-shape.h"
static const NSTimeInterval RFClockFaceInterval = 1.0 / 20.0;
static void RFClockFaceFill(CALayer *layer, UIImage *image, CGSize size) {
    layer.hidden = !image;
    if (!image) return;
    CGImageRef cgImage = image.CGImage;
    CGFloat factor = size.height / (CGFloat)CGImageGetHeight(cgImage);
    layer.contents = (__bridge id)cgImage;
    layer.contentsGravity = kCAGravityResize;
    layer.minificationFilter = kCAFilterTrilinear;
    layer.magnificationFilter = kCAFilterLinear;
    layer.bounds = CGRectMake(0, 0, CGImageGetWidth(cgImage) * factor, size.height);
    layer.position = CGPointMake(size.width / 2, size.height / 2);
}
@implementation RFClockFaceView {
    CALayer *_hourLayer;
    CALayer *_minuteLayer;
    CALayer *_secondLayer;
    CALayer *_capLayer;
    CAShapeLayer *_shape;
    UIImage *_hourImage;
    UIImage *_minuteImage;
    UIImage *_secondImage;
    UIImage *_capImage;
    NSTimer *_timer;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    _hourLayer = [CALayer layer];
    _minuteLayer = [CALayer layer];
    _secondLayer = [CALayer layer];
    _capLayer = [CALayer layer];
    for (CALayer *layer in @[_hourLayer, _minuteLayer, _secondLayer, _capLayer]) [self.layer addSublayer:layer];
    _shape = [CAShapeLayer layer];
    self.layer.mask = _shape;
    [self reloadImages];
    return self;
}
- (void)dealloc {
    [_timer invalidate];
}
- (void)reloadImages {
    UIImage *background = RFIconImage(@"Clock", @"bg");
    self.layer.contents = background ? (__bridge id)background.CGImage : nil;
    self.layer.contentsGravity = kCAGravityResize;
    self.layer.minificationFilter = kCAFilterTrilinear;
    _hourImage = RFIconImage(@"Clock", @"hour");
    _minuteImage = RFIconImage(@"Clock", @"min");
    _secondImage = RFIconImage(@"Clock", @"sec");
    _capImage = RFIconImage(@"Clock", @"cap");
    [self fillLayers];
}
- (void)fillLayers {
    CGSize size = self.bounds.size;
    if (size.width < 1 || size.height < 1) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _shape.frame = self.bounds;
    _shape.path = RFIconShapePath(self.bounds).CGPath;
    RFClockFaceFill(_hourLayer, _hourImage, size);
    RFClockFaceFill(_minuteLayer, _minuteImage, size);
    RFClockFaceFill(_secondLayer, _secondImage, size);
    RFClockFaceFill(_capLayer, _capImage, size);
    [CATransaction commit];
    [self tick];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self fillLayers];
}
- (void)tick {
    NSCalendarUnit units = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond;
    NSDateComponents *time = [[NSCalendar autoupdatingCurrentCalendar] components:units fromDate:[NSDate date]];
    double second = time.second + time.nanosecond / 1e9;
    double minute = time.minute + second / 60.0;
    double hour = (time.hour % 12) + minute / 60.0;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _secondLayer.affineTransform = CGAffineTransformMakeRotation(second / 60.0 * 2 * M_PI);
    _minuteLayer.affineTransform = CGAffineTransformMakeRotation(minute / 60.0 * 2 * M_PI);
    _hourLayer.affineTransform = CGAffineTransformMakeRotation(hour / 12.0 * 2 * M_PI);
    [CATransaction commit];
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_timer invalidate];
    _timer = nil;
    if (!self.window) return;
    [self tick];
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer timerWithTimeInterval:RFClockFaceInterval repeats:YES block:^(NSTimer *timer) {
        [weakSelf tick];
    }];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}
@end
