#import "CelebrationView.h"
#import <QuartzCore/QuartzCore.h>
static NSString *const kMessage = @"Congrats Reagan!";
@interface CelebrationView ()
@property(nonatomic, strong) UIView *wordArt;
@property(nonatomic, strong) NSArray<UIView *> *letters;
@property(nonatomic) BOOL looping;
@property(nonatomic, strong) NSArray<UIImageView *> *stars;
@property(nonatomic, strong) UILabel *stats;
@property(nonatomic, strong) CAEmitterLayer *confetti;
@property(nonatomic) CGFloat artWidth;
@property(nonatomic) BOOL showing;
@end
@implementation CelebrationView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.hidden = YES;
        _wordArt = [UIView new];
        _wordArt.isAccessibilityElement = YES;
        _wordArt.accessibilityLabel = kMessage;
        [self addSubview:_wordArt];
        NSMutableArray *stars = [NSMutableArray array];
        for (UIColor *color in @[
                 [UIColor colorWithRed:1 green:0.89 blue:0.2 alpha:1], [UIColor colorWithRed:1 green:0.42 blue:0.75 alpha:1],
                 [UIColor colorWithRed:0.3 green:0.85 blue:1 alpha:1], [UIColor colorWithRed:1 green:0.89 blue:0.2 alpha:1]
             ]) {
            UIImageView *star = [[UIImageView alloc] initWithImage:[CelebrationView starOfSize:64 color:color]];
            [stars addObject:star];
            [self addSubview:star];
        }
        _stars = stars;
        _stats = [UILabel new];
        _stats.textAlignment = NSTextAlignmentCenter;
        _stats.numberOfLines = 0;
        [self addSubview:_stats];
    }
    return self;
}
// Classic 90s WordArt: letters on an upward arch, each filled with a top-to-bottom rainbow, a thick navy
// outline, a deep purple extrusion, and a drop shadow. Each letter is its own image so they can bounce
// separately; drawing left to right, each letter's face covers its left neighbor's extrusion, as in one image.
+ (NSArray<UIImageView *> *)wordArtLettersForWidth:(CGFloat)width canvas:(CGSize *)canvas {
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:100] ?: [UIFont boldSystemFontOfSize:100];
    font = [font fontWithSize:floor(100 * width * 0.84 / [kMessage sizeWithAttributes:@{NSFontAttributeName : font}].width)];
    NSDictionary *plain = @{NSFontAttributeName : font};
    CGFloat size = font.pointSize, stretch = 1.3, depth = MAX(5, round(size * 0.08)), arc = 0.7;
    CGFloat total = [kMessage sizeWithAttributes:plain].width, radius = total / arc;
    CGFloat height = font.lineHeight * stretch, top = size * 0.12 + height / 2;
    *canvas = CGSizeMake(width, ceil(top + height / 2 + radius * (1 - cos(arc / 2)) + depth + size * 0.12));
    UIColor *navy = [UIColor colorWithRed:0.1 green:0.08 blue:0.4 alpha:1],
            *extrusion = [UIColor colorWithRed:0.3 green:0.1 blue:0.45 alpha:1];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat colors[] = {0.95, 0.1, 0.18, 1, 1, 0.55, 0.05, 1, 1, 0.92, 0.12, 1,
                        0.2, 0.82, 0.25, 1, 0.12, 0.5, 1, 1, 0.6, 0.22, 0.9, 1},
            locations[] = {0.05, 0.25, 0.45, 0.6, 0.78, 0.98};
    CGGradientRef rainbow = CGGradientCreateWithColorComponents(space, colors, locations, 6);
    NSMutableArray<UIImageView *> *views = [NSMutableArray array];
    CGFloat x = 0;
    for (NSUInteger i = 0; i < kMessage.length; i++) {
        NSString *ch = [kMessage substringWithRange:NSMakeRange(i, 1)];
        CGSize s = [ch sizeWithAttributes:plain];
        CGFloat angle = (x + s.width / 2 - total / 2) / radius;
        CGPoint c = CGPointMake(width / 2 + radius * sin(angle), top + radius * (1 - cos(angle)));
        x += s.width;
        if ([ch isEqualToString:@" "])
            continue;
        CGFloat r = hypot(s.width, s.height * stretch) / 2 + size * 0.06;
        CGRect box = CGRectIntegral(CGRectMake(c.x - r - 4, c.y - r - 4, 2 * r + depth * 0.55 + 22, 2 * r + depth + 24));
        // Runs body in the letter's upright, stretched frame, centered on its line box.
        void (^place)(CGSize, void (^)(void)) = ^(CGSize offset, void (^body)(void)) {
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, c.x - box.origin.x + offset.width, c.y - box.origin.y + offset.height);
            CGContextRotateCTM(ctx, angle);
            CGContextScaleCTM(ctx, 1, stretch);
            body();
            CGContextRestoreGState(ctx);
        };
        void (^draw)(NSDictionary *, CGSize) = ^(NSDictionary *attributes, CGSize offset) {
            place(offset, ^{
                [ch drawAtPoint:CGPointMake(-s.width / 2, -s.height / 2) withAttributes:attributes];
            });
        };
        // The rainbow: a white letter, then the gradient painted only where it is opaque.
        UIGraphicsBeginImageContextWithOptions(box.size, NO, 0);
        draw(@{NSFontAttributeName : font, NSForegroundColorAttributeName : [UIColor whiteColor]}, CGSizeZero);
        CGContextSetBlendMode(UIGraphicsGetCurrentContext(), kCGBlendModeSourceIn);
        place(CGSizeZero, ^{
            CGFloat baseline = -s.height / 2 + font.ascender;
            CGContextDrawLinearGradient(UIGraphicsGetCurrentContext(), rainbow, CGPointMake(0, baseline - font.capHeight),
                                        CGPointMake(0, baseline),
                                        kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        });
        UIImage *fill = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIGraphicsBeginImageContextWithOptions(box.size, NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetShadowWithColor(ctx, CGSizeMake(4, 7), 6, [UIColor colorWithWhite:0 alpha:0.55].CGColor);
        CGContextBeginTransparencyLayer(ctx, NULL);
        for (CGFloat k = depth; k >= 1; k--)
            draw(@{
                NSFontAttributeName : font, NSForegroundColorAttributeName : extrusion,
                NSStrokeColorAttributeName : extrusion, NSStrokeWidthAttributeName : @-9
            },
                 CGSizeMake(k * 0.55, k));
        draw(@{
            NSFontAttributeName : font, NSForegroundColorAttributeName : navy, NSStrokeColorAttributeName : navy,
            NSStrokeWidthAttributeName : @-9
        },
             CGSizeZero);
        [fill drawAtPoint:CGPointZero];
        draw(@{
            NSFontAttributeName : font, NSStrokeColorAttributeName : [UIColor colorWithWhite:1 alpha:0.75],
            NSStrokeWidthAttributeName : @1.5
        },
             CGSizeZero);
        CGContextEndTransparencyLayer(ctx);
        UIImageView *view = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
        UIGraphicsEndImageContext();
        view.frame = box;
        [views addObject:view];
    }
    CGGradientRelease(rainbow);
    CGColorSpaceRelease(space);
    return views;
}
// A cartoon star: thick black outline and a shine, straight out of a clip-art CD.
+ (UIImage *)starOfSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGPoint c = CGPointMake(size / 2, size * 0.53);
    CGFloat outer = size * 0.44, inner = outer * 0.46;
    UIBezierPath *star = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < 10; i++) {
        CGFloat r = i % 2 ? inner : outer, a = -M_PI_2 + i * M_PI / 5;
        CGPoint p = CGPointMake(c.x + r * cos(a), c.y + r * sin(a));
        if (i)
            [star addLineToPoint:p];
        else
            [star moveToPoint:p];
    }
    [star closePath];
    star.lineJoinStyle = kCGLineJoinRound;
    star.lineWidth = size * 0.06;
    [color setFill];
    [star fill];
    [[UIColor colorWithWhite:0.05 alpha:1] setStroke];
    [star stroke];
    [[UIColor colorWithWhite:1 alpha:0.85] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(c.x - outer * 0.32, c.y - outer * 0.42, outer * 0.2, outer * 0.32)] fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
+ (UIImage *)pieceOfSize:(CGSize)size round:(BOOL)round {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [[UIColor whiteColor] setFill];
    CGRect r = (CGRect){CGPointZero, size};
    [(round ? [UIBezierPath bezierPathWithOvalInRect:r] : [UIBezierPath bezierPathWithRect:r]) fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
- (CAEmitterLayer *)makeConfetti {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.emitterShape = kCAEmitterLayerLine;
    emitter.beginTime = CACurrentMediaTime();
    NSArray<UIImage *> *pieces = @[
        [CelebrationView pieceOfSize:CGSizeMake(12, 7) round:NO], [CelebrationView pieceOfSize:CGSizeMake(5, 14) round:NO],
        [CelebrationView pieceOfSize:CGSizeMake(8, 8) round:YES]
    ];
    NSArray<UIColor *> *colors = @[
        [UIColor colorWithRed:0.96 green:0.16 blue:0.2 alpha:1], [UIColor colorWithRed:1 green:0.6 blue:0.1 alpha:1],
        [UIColor colorWithRed:1 green:0.9 blue:0.2 alpha:1], [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1],
        [UIColor colorWithRed:0.2 green:0.55 blue:1 alpha:1], [UIColor colorWithRed:0.7 green:0.35 blue:1 alpha:1],
        [UIColor colorWithRed:1 green:0.45 blue:0.8 alpha:1], [UIColor whiteColor]
    ];
    NSMutableArray *cells = [NSMutableArray array];
    for (NSUInteger i = 0; i < colors.count; i++) {
        CAEmitterCell *cell = [CAEmitterCell emitterCell];
        cell.contents = (id)pieces[i % pieces.count].CGImage;
        cell.color = colors[i].CGColor;
        cell.birthRate = 6;
        cell.lifetime = 9;
        cell.velocity = 170;
        cell.velocityRange = 90;
        cell.emissionLongitude = M_PI_2;
        cell.emissionRange = M_PI / 5;
        cell.yAcceleration = 70;
        cell.xAcceleration = i % 2 ? 8 : -8;
        cell.spin = 3;
        cell.spinRange = 8;
        cell.scale = 1;
        cell.scaleRange = 0.45;
        [cells addObject:cell];
    }
    emitter.emitterCells = cells;
    return emitter;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    CGFloat width = MIN(size.width - 40, 840);
    if (self.showing && width != self.artWidth) {
        self.artWidth = width;
        [self buildWordArt];
    }
    CGSize art = self.wordArt.bounds.size;
    self.wordArt.center = CGPointMake(size.width / 2, (size.height - self.bottomInset) * 0.4);
    CGRect frame = CGRectMake(self.wordArt.center.x - art.width / 2, self.wordArt.center.y - art.height / 2,
                              art.width, art.height);
    CGPoint spots[] = {{CGRectGetMinX(frame) + 6, CGRectGetMinY(frame) + 4}, {CGRectGetMaxX(frame) - 6, CGRectGetMinY(frame) + 4},
                       {CGRectGetMinX(frame) + 40, CGRectGetMaxY(frame) - 6}, {CGRectGetMaxX(frame) - 40, CGRectGetMaxY(frame) - 6}};
    for (NSUInteger i = 0; i < self.stars.count; i++)
        self.stars[i].center = spots[i];
    self.stats.frame = CGRectMake(20, size.height - self.bottomInset - 84, size.width - 40, 76);
    self.confetti.emitterPosition = CGPointMake(size.width / 2, -20);
    self.confetti.emitterSize = CGSizeMake(size.width, 1);
}
- (void)buildWordArt {
    for (UIView *letter in self.letters)
        [letter removeFromSuperview];
    CGSize canvas;
    self.letters = [CelebrationView wordArtLettersForWidth:self.artWidth canvas:&canvas];
    self.wordArt.bounds = (CGRect){CGPointZero, canvas};
    for (UIView *letter in self.letters)
        [self.wordArt addSubview:letter];
    if (self.looping)
        [self loopLetters];
}
- (void)showWithTime:(NSString *)time moves:(NSInteger)moves hint:(NSString *)hint {
    UIColor *edge = [UIColor colorWithRed:0.02 green:0.14 blue:0.05 alpha:1];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:[NSString stringWithFormat:@"%@   ·   %ld moves\n", time, (long)moves]
            attributes:@{
                NSFontAttributeName : [UIFont fontWithName:@"ChalkboardSE-Bold" size:28],
                NSForegroundColorAttributeName : [UIColor colorWithRed:1 green:0.9 blue:0.3 alpha:1],
                NSStrokeColorAttributeName : edge, NSStrokeWidthAttributeName : @-4
            }];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:hint
                                                                 attributes:@{
                                                                     NSFontAttributeName : [UIFont fontWithName:@"ChalkboardSE-Regular" size:17],
                                                                     NSForegroundColorAttributeName : [UIColor whiteColor],
                                                                     NSStrokeColorAttributeName : edge,
                                                                     NSStrokeWidthAttributeName : @-3
                                                                 }]];
    self.stats.attributedText = text;
    if (self.showing)
        return;
    self.showing = YES;
    self.hidden = NO;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    if (UIAccessibilityIsReduceMotionEnabled())
        return;
    self.confetti = [self makeConfetti];
    [self.layer insertSublayer:self.confetti atIndex:0];
    [self setNeedsLayout];
    // A heavy first burst, then a steady fall.
    self.confetti.birthRate = 4;
    CAEmitterLayer *confetti = self.confetti;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        confetti.birthRate = 1;
    });
    // The letters drop in one by one and land with a bounce; the stars pop in around them.
    for (NSUInteger i = 0; i < self.letters.count; i++) {
        UIView *letter = self.letters[i];
        letter.transform = CGAffineTransformMakeTranslation(0, -self.bounds.size.height * 0.6);
        letter.alpha = 0;
        [UIView animateWithDuration:0.8
                              delay:0.1 + i * 0.06
             usingSpringWithDamping:0.45
              initialSpringVelocity:0.4
                            options:0
                         animations:^{
                             letter.transform = CGAffineTransformIdentity;
                             letter.alpha = 1;
                         }
                         completion:nil];
    }
    for (UIView *star in self.stars) {
        star.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(0.05, 0.05), -0.4);
        star.alpha = 0;
    }
    [UIView animateWithDuration:0.9
        delay:0.1 + self.letters.count * 0.06
        usingSpringWithDamping:0.5
        initialSpringVelocity:0.6
        options:0
        animations:^{
            for (UIView *star in self.stars) {
                star.transform = CGAffineTransformIdentity;
                star.alpha = 1;
            }
        }
        completion:^(BOOL finished) {
            if (self.showing)
                [self startLooping];
        }];
}
+ (CABasicAnimation *)swing:(NSString *)keyPath by:(CGFloat)amount duration:(CFTimeInterval)duration {
    CABasicAnimation *swing = [CABasicAnimation animationWithKeyPath:keyPath];
    swing.fromValue = @(-amount);
    swing.toValue = @(amount);
    swing.duration = duration;
    swing.autoreverses = YES;
    swing.repeatCount = HUGE_VALF;
    swing.additive = YES;
    swing.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    return swing;
}
// A wave runs through the letters, each hopping and wiggling a beat after the one before.
- (void)loopLetters {
    CFTimeInterval now = CACurrentMediaTime();
    CGFloat hop = self.wordArt.bounds.size.height * 0.07;
    for (NSUInteger i = 0; i < self.letters.count; i++) {
        CABasicAnimation *bounce = [CelebrationView swing:@"transform.translation.y" by:hop duration:0.42];
        CABasicAnimation *wiggle = [CelebrationView swing:@"transform.rotation.z" by:0.09 duration:0.56];
        bounce.beginTime = wiggle.beginTime = now + i * 0.07;
        bounce.fillMode = wiggle.fillMode = kCAFillModeBackwards;
        [self.letters[i].layer addAnimation:bounce forKey:@"bounce"];
        [self.letters[i].layer addAnimation:wiggle forKey:@"wiggle"];
    }
}
- (void)startLooping {
    self.looping = YES;
    [self loopLetters];
    // The whole message floats on a slow loop around its spot, rocking and pulsing as it goes.
    CAKeyframeAnimation *drift = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    CGFloat dx = MIN(40, (self.bounds.size.width - self.wordArt.bounds.size.width) / 2), dy = 14;
    drift.path = CGPathCreateWithEllipseInRect(CGRectMake(-dx, -dy, 2 * dx, 2 * dy), NULL);
    CGPathRelease(drift.path);
    drift.additive = YES;
    drift.calculationMode = kCAAnimationPaced;
    drift.duration = 6;
    drift.repeatCount = HUGE_VALF;
    [self.wordArt.layer addAnimation:drift forKey:@"drift"];
    [self.wordArt.layer addAnimation:[CelebrationView swing:@"transform.rotation.z" by:0.04 duration:1.6] forKey:@"rock"];
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @1;
    pulse.toValue = @1.06;
    pulse.duration = 0.7;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.wordArt.layer addAnimation:pulse forKey:@"loop"];
    for (NSUInteger i = 0; i < self.stars.count; i++) {
        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.toValue = @(i % 2 ? -2 * M_PI : 2 * M_PI);
        spin.duration = 3 + i * 0.4;
        spin.repeatCount = HUGE_VALF;
        CABasicAnimation *twinkle = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        twinkle.fromValue = @0.8;
        twinkle.toValue = @1.15;
        twinkle.duration = 0.5 + i * 0.07;
        twinkle.autoreverses = YES;
        twinkle.repeatCount = HUGE_VALF;
        [self.stars[i].layer addAnimation:spin forKey:@"spin"];
        [self.stars[i].layer addAnimation:twinkle forKey:@"loop"];
    }
}
- (void)hide {
    if (!self.showing)
        return;
    self.showing = NO;
    self.looping = NO;
    self.hidden = YES;
    [self.confetti removeFromSuperlayer];
    self.confetti = nil;
    NSArray *views = [[@[ self.wordArt ] arrayByAddingObjectsFromArray:self.stars] arrayByAddingObjectsFromArray:self.letters];
    for (UIView *view in views) {
        [view.layer removeAllAnimations];
        view.transform = CGAffineTransformIdentity;
        view.alpha = 1;
    }
}
@end
