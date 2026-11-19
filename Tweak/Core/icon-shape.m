#import "icon-shape.h"

static const CGFloat RFIconRadiusRatio = 0.2237;
static const CGFloat RFIconSmoothing = 0.6;

static CGPoint RFIconPoint(CGPoint origin, CGPoint along, CGFloat distance, CGPoint across, CGFloat offset) {
    return CGPointMake(origin.x + along.x * distance + across.x * offset,
                       origin.y + along.y * distance + across.y * offset);
}

static void RFIconAddCorner(UIBezierPath *path, CGPoint corner, CGPoint along, CGPoint across, CGFloat radius) {
    CGFloat arc = M_PI_2 * (1 - RFIconSmoothing);
    CGFloat arcLength = sin(arc / 2) * radius * M_SQRT2;
    CGFloat tail = radius * tan((M_PI_2 - arc) / 4);
    CGFloat angle = M_PI_4 * RFIconSmoothing;
    CGFloat c = tail * cos(angle);
    CGFloat d = c * tan(angle);
    CGFloat p = (1 + RFIconSmoothing) * radius;
    CGFloat b = (p - arcLength - c - d) / 3;
    CGFloat a = 2 * b;

    CGPoint start = RFIconPoint(corner, along, -p, across, 0);
    if ([path isEmpty]) {
        [path moveToPoint:start];
    } else {
        [path addLineToPoint:start];
    }

    CGPoint first = RFIconPoint(start, along, a + b + c, across, d);
    [path addCurveToPoint:first
            controlPoint1:RFIconPoint(start, along, a, across, 0)
            controlPoint2:RFIconPoint(start, along, a + b, across, 0)];

    CGPoint second = RFIconPoint(first, along, arcLength, across, arcLength);
    CGPoint middle = CGPointMake((first.x + second.x) / 2, (first.y + second.y) / 2);
    CGFloat depth = radius * cos(arc / 2);
    CGPoint center = CGPointMake(middle.x + (across.x - along.x) / M_SQRT2 * depth,
                                 middle.y + (across.y - along.y) / M_SQRT2 * depth);
    CGFloat from = atan2(first.y - center.y, first.x - center.x);
    [path addArcWithCenter:center radius:radius startAngle:from endAngle:from + arc clockwise:YES];

    CGPoint end = RFIconPoint(second, along, d, across, a + b + c);
    [path addCurveToPoint:end
            controlPoint1:RFIconPoint(second, along, d, across, c)
            controlPoint2:RFIconPoint(second, along, d, across, b + c)];
}

UIBezierPath *RFIconShapePath(CGRect rect) {
    CGFloat radius = MIN(rect.size.width, rect.size.height) * RFIconRadiusRatio;
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);

    UIBezierPath *path = [UIBezierPath bezierPath];
    RFIconAddCorner(path, CGPointMake(maxX, minY), CGPointMake(1, 0), CGPointMake(0, 1), radius);
    RFIconAddCorner(path, CGPointMake(maxX, maxY), CGPointMake(0, 1), CGPointMake(-1, 0), radius);
    RFIconAddCorner(path, CGPointMake(minX, maxY), CGPointMake(-1, 0), CGPointMake(0, -1), radius);
    RFIconAddCorner(path, CGPointMake(minX, minY), CGPointMake(0, -1), CGPointMake(1, 0), radius);
    [path closePath];
    return path;
}
