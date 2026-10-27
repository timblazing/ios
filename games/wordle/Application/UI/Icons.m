#import "Icons.h"

static void Circle(UIBezierPath *path, CGPoint c, CGFloat r) {
    [path moveToPoint:CGPointMake(c.x + r, c.y)];
    [path addArcWithCenter:c radius:r startAngle:0 endAngle:2 * M_PI clockwise:YES];
}

static void Draw(NSString *name) {
    UIBezierPath *stroke = [UIBezierPath bezierPath], *fill = [UIBezierPath bezierPath];
    stroke.lineWidth = 2;
    stroke.lineCapStyle = kCGLineCapRound;
    stroke.lineJoinStyle = kCGLineJoinRound;
    if ([name isEqualToString:@"menu"]) {
        for (CGFloat y = 6; y <= 18; y += 6) {
            [stroke moveToPoint:CGPointMake(3, y)];
            [stroke addLineToPoint:CGPointMake(21, y)];
        }
    } else if ([name isEqualToString:@"help"]) {
        Circle(stroke, CGPointMake(12, 12), 9.5);
        [stroke stroke];
        NSDictionary *attrs = @{
            NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Bold" size:13],
            NSForegroundColorAttributeName : [UIColor blackColor]
        };
        CGSize size = [@"?" sizeWithAttributes:attrs];
        [@"?" drawAtPoint:CGPointMake(12 - size.width / 2, 12 - size.height / 2) withAttributes:attrs];
        return;
    } else if ([name isEqualToString:@"stats"]) {
        [fill appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(3, 11, 5, 10)]];
        [fill appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(9.5, 4, 5, 17)]];
        [fill appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(16, 8, 5, 13)]];
    } else if ([name isEqualToString:@"settings"]) {
        // Eight square teeth around a ring with a hole.
        CGPoint c = CGPointMake(12, 12);
        for (int k = 0; k < 16; k++) {
            CGFloat r = k % 2 ? 7.8 : 10.4, a0 = (k * 22.5 - 11.25) * M_PI / 180, a1 = a0 + 22.5 * M_PI / 180;
            CGPoint p = CGPointMake(c.x + r * cos(a0), c.y + r * sin(a0));
            k ? [fill addLineToPoint:p] : [fill moveToPoint:p];
            [fill addArcWithCenter:c radius:r startAngle:a0 endAngle:a1 clockwise:YES];
        }
        [fill closePath];
        Circle(fill, c, 3.6);
        fill.usesEvenOddFillRule = YES;
    } else if ([name isEqualToString:@"close"]) {
        [stroke moveToPoint:CGPointMake(6, 6)];
        [stroke addLineToPoint:CGPointMake(18, 18)];
        [stroke moveToPoint:CGPointMake(18, 6)];
        [stroke addLineToPoint:CGPointMake(6, 18)];
    } else if ([name isEqualToString:@"backspace"]) {
        [stroke moveToPoint:CGPointMake(8, 5)];
        [stroke addLineToPoint:CGPointMake(21, 5)];
        [stroke addLineToPoint:CGPointMake(21, 19)];
        [stroke addLineToPoint:CGPointMake(8, 19)];
        [stroke addLineToPoint:CGPointMake(2, 12)];
        [stroke closePath];
        [stroke moveToPoint:CGPointMake(11.5, 9)];
        [stroke addLineToPoint:CGPointMake(17.5, 15)];
        [stroke moveToPoint:CGPointMake(17.5, 9)];
        [stroke addLineToPoint:CGPointMake(11.5, 15)];
    } else if ([name isEqualToString:@"share"]) {
        CGPoint a = CGPointMake(18, 5), b = CGPointMake(6, 12), c = CGPointMake(18, 19);
        Circle(fill, a, 3);
        Circle(fill, b, 3);
        Circle(fill, c, 3);
        [stroke moveToPoint:a];
        [stroke addLineToPoint:b];
        [stroke addLineToPoint:c];
    }
    [[UIColor blackColor] set];
    [stroke stroke];
    [fill fill];
}

UIImage *Icon(NSString *name) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
    });
    UIImage *image = [cache objectForKey:name];
    if (image)
        return image;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0);
    Draw(name);
    image = [UIGraphicsGetImageFromCurrentImageContext() imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIGraphicsEndImageContext();
    [cache setObject:image forKey:name];
    return image;
}
