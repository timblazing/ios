#import "GameControls.h"
static const CGFloat kIconSize = 24;
@interface GameControls ()
@property(nonatomic, strong) UIView *rule;
@end
@implementation GameControls
typedef NS_ENUM(NSInteger, ControlIcon) { ControlIconUndo, ControlIconNewGame, ControlIconSettings };
// Icons are drawn in code on a 24pt grid, so they need no assets and stay sharp at any scale.
+ (void)drawIcon:(ControlIcon)icon {
    UIBezierPath *stroke = [UIBezierPath bezierPath], *fill = [UIBezierPath bezierPath];
    stroke.lineWidth = 2;
    stroke.lineCapStyle = kCGLineCapRound;
    stroke.lineJoinStyle = kCGLineJoinRound;
    if (icon == ControlIconUndo) {
        [stroke moveToPoint:CGPointMake(9, 4)];
        [stroke addLineToPoint:CGPointMake(4, 9)];
        [stroke addLineToPoint:CGPointMake(9, 14)];
        [stroke moveToPoint:CGPointMake(4.5, 9)];
        [stroke addLineToPoint:CGPointMake(13, 9)];
        [stroke addArcWithCenter:CGPointMake(13, 15) radius:6 startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:YES];
        [stroke addLineToPoint:CGPointMake(7, 21)];
    } else if (icon == ControlIconNewGame) {
        CGFloat start = -M_PI / 3, end = M_PI * 1.28, radius = 7.5;
        CGPoint center = CGPointMake(12, 12);
        [stroke addArcWithCenter:center radius:radius startAngle:start endAngle:end clockwise:YES];
        // Arrowhead at the end of the arc, pointing along the direction of travel.
        CGPoint tip = CGPointMake(center.x + radius * cos(end), center.y + radius * sin(end));
        CGVector t = CGVectorMake(-sin(end), cos(end)), n = CGVectorMake(-t.dy, t.dx);
        [fill moveToPoint:CGPointMake(tip.x + t.dx * 5, tip.y + t.dy * 5)];
        [fill addLineToPoint:CGPointMake(tip.x - t.dx * 1 + n.dx * 4.5, tip.y - t.dy * 1 + n.dy * 4.5)];
        [fill addLineToPoint:CGPointMake(tip.x - t.dx * 1 - n.dx * 4.5, tip.y - t.dy * 1 - n.dy * 4.5)];
        [fill closePath];
    } else {
        CGPoint c = CGPointMake(12, 12);
        CGFloat base = 8.2, top = 10.8, baseHalf = 0.34, topHalf = 0.2;
        for (NSInteger i = 0; i < 8; i++) {
            CGFloat a = i * M_PI_4;
            CGPoint p0 = CGPointMake(c.x + base * cos(a - baseHalf), c.y + base * sin(a - baseHalf));
            if (i == 0)
                [fill moveToPoint:p0];
            else
                [fill addArcWithCenter:c radius:base startAngle:a - M_PI_4 + baseHalf endAngle:a - baseHalf clockwise:YES];
            [fill addLineToPoint:CGPointMake(c.x + top * cos(a - topHalf), c.y + top * sin(a - topHalf))];
            [fill addLineToPoint:CGPointMake(c.x + top * cos(a + topHalf), c.y + top * sin(a + topHalf))];
            [fill addLineToPoint:CGPointMake(c.x + base * cos(a + baseHalf), c.y + base * sin(a + baseHalf))];
        }
        [fill addArcWithCenter:c radius:base startAngle:7 * M_PI_4 + baseHalf endAngle:2 * M_PI - baseHalf clockwise:YES];
        [fill closePath];
        [fill appendPath:[UIBezierPath bezierPathWithArcCenter:c radius:3.6 startAngle:0 endAngle:2 * M_PI clockwise:YES]];
        fill.usesEvenOddFillRule = YES;
    }
    [stroke stroke];
    [fill fill];
}
+ (UIImage *)imageForIcon:(ControlIcon)icon color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kIconSize, kIconSize), NO, 0);
    [color setStroke];
    [color setFill];
    [self drawIcon:icon];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}
+ (UIColor *)gold {
    return [UIColor colorWithRed:1 green:0.82 blue:0.25 alpha:1];
}
// A 36pt pill centered in a 44pt-tall image, so the button looks slim but keeps a 44pt tap target.
+ (UIImage *)pillWithColor:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(37, 44), NO, 0);
    [color setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 4, 37, 36) cornerRadius:18] fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0, 18, 0, 18)];
}
- (UIButton *)buttonWithIcon:(ControlIcon)icon label:(NSString *)label {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setImage:[GameControls imageForIcon:icon color:[UIColor whiteColor]] forState:UIControlStateNormal];
    [b setImage:[GameControls imageForIcon:icon color:[GameControls gold]] forState:UIControlStateHighlighted];
    [b setImage:[GameControls imageForIcon:icon color:[UIColor colorWithWhite:1 alpha:0.3]]
       forState:UIControlStateDisabled];
    b.accessibilityLabel = label;
    [self addSubview:b];
    return b;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithRed:0.02 green:0.13 blue:0.06 alpha:0.9];
        _rule = [UIView new];
        _rule.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
        [self addSubview:_rule];
        _undoButton = [self buttonWithIcon:ControlIconUndo label:@"Undo"];
        _restartButton = [self buttonWithIcon:ControlIconNewGame label:@"New game"];
        _settingsButton = [self buttonWithIcon:ControlIconSettings label:@"Settings"];
        // A gold pill, so the one-tap finish is hard to miss when it appears.
        _autoWinButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_autoWinButton setTitle:@"Auto Win" forState:UIControlStateNormal];
        _autoWinButton.titleLabel.font = [UIFont fontWithName:@"AvenirNext-Bold" size:16];
        [_autoWinButton setTitleColor:[UIColor colorWithRed:0.06 green:0.2 blue:0.09 alpha:1]
                             forState:UIControlStateNormal];
        [_autoWinButton setBackgroundImage:[GameControls pillWithColor:[GameControls gold]]
                                  forState:UIControlStateNormal];
        [_autoWinButton setBackgroundImage:[GameControls pillWithColor:[UIColor colorWithRed:0.85 green:0.66 blue:0.12 alpha:1]]
                                  forState:UIControlStateHighlighted];
        _autoWinButton.accessibilityLabel = @"Auto win";
        _autoWinButton.hidden = YES;
        [self addSubview:_autoWinButton];
        _status = [UILabel new];
        _status.textColor = [UIColor colorWithWhite:1 alpha:0.9];
        _status.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular];
        [self addSubview:_status];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height, button = 56;
    self.rule.frame = CGRectMake(0, 0, w, 1 / [UIScreen mainScreen].scale);
    CGFloat pill = 112, pillX = w - 3 * button - 12 - pill - 8;
    self.autoWinButton.frame = CGRectMake(pillX, (h - 44) / 2, pill, 44);
    self.status.frame = CGRectMake(24, 0, MAX(0, pillX - 24 - 12), h);
    self.undoButton.frame = CGRectMake(w - 3 * button - 12, 0, button, h);
    self.restartButton.frame = CGRectMake(w - 2 * button - 12, 0, button, h);
    self.settingsButton.frame = CGRectMake(w - button - 12, 0, button, h);
}
@end
