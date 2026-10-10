#import "RTStyle.h"

static UIColor *RGB(int hex) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1];
}

@implementation RTStyle
+ (UIColor *)orange { return RGB(0xE2701B); }
+ (UIColor *)blue { return RGB(0x1C77BC); }
+ (UIColor *)green { return RGB(0x3A9036); }
+ (UIColor *)red { return RGB(0xC9282A); }
+ (UIColor *)yellow { return RGB(0xF2C230); }
+ (UIColor *)paper { return RGB(0xF3EDDF); }
+ (UIColor *)ink { return RGB(0x221D18); }
+ (UIColor *)bandColor:(NSUInteger)index {
    NSArray *c = @[self.orange, self.blue, self.green, self.red];
    return c[index % c.count];
}
+ (UIFont *)stencil:(CGFloat)size { return [UIFont fontWithName:@"Futura-CondensedExtraBold" size:size] ?: [UIFont boldSystemFontOfSize:size]; }
+ (UIFont *)type:(CGFloat)size { return [UIFont fontWithName:@"AmericanTypewriter" size:size] ?: [UIFont systemFontOfSize:size]; }
+ (UIFont *)typeBold:(CGFloat)size { return [UIFont fontWithName:@"AmericanTypewriter-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size]; }
+ (NSAttributedString *)spaced:(NSString *)text font:(UIFont *)font color:(UIColor *)color kern:(CGFloat)kern {
    return [[NSAttributedString alloc] initWithString:text ?: @"" attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSKernAttributeName: @(kern)}];
}
+ (BOOL)reduceMotion { return UIAccessibilityIsReduceMotionEnabled(); }

+ (NSCache *)cache {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        cache.countLimit = 6;  // decoded 1920px stills are ~8 MB each; keep only a few on a 1 GB device
    });
    return cache;
}

+ (NSString *)pathForName:(NSString *)name {
    NSString *file = [name hasPrefix:@"cast/"] ? [@"cast-" stringByAppendingString:[name substringFromIndex:5]] : [@"still-" stringByAppendingString:name];
    return [[NSBundle mainBundle] pathForResource:file ofType:@"jpg" inDirectory:@"Media"];
}

+ (UIImage *)decoded:(UIImage *)image {
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
    [image drawAtPoint:CGPointZero];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out;
}

+ (UIImage *)imageNamed:(NSString *)name {
    if (!name) return nil;
    UIImage *image = [self.cache objectForKey:name];
    if (!image) {
        image = [self decoded:[UIImage imageWithContentsOfFile:[self pathForName:name]]];
        if (image) [self.cache setObject:image forKey:name];
    }
    return image;
}

+ (void)loadImageNamed:(NSString *)name completion:(void (^)(UIImage *))completion {
    UIImage *cached = name ? [self.cache objectForKey:name] : nil;
    if (cached || !name) {
        if (completion) completion(cached);
        return;
    }
    NSString *path = [self pathForName:name];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *image = [self decoded:[UIImage imageWithContentsOfFile:path]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) [self.cache setObject:image forKey:name];
            if (completion) completion(image);
        });
    });
}

+ (UIImage *)logo {
    static UIImage *logo;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        logo = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"logo" ofType:@"png" inDirectory:@"Media"]];
    });
    return logo;
}
@end

@implementation RTBackdropView {
    CAGradientLayer *_wash;
    NSString *_name;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.blackColor;
        self.clipsToBounds = YES;
        _imageView = [UIImageView new];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_imageView];
        _wash = [CAGradientLayer layer];
        [self.layer addSublayer:_wash];
        self.dim = 0.6;
    }
    return self;
}

- (void)setDim:(CGFloat)dim {
    _dim = dim;
    _wash.colors = @[(id)[UIColor colorWithWhite:0 alpha:dim * 0.8].CGColor, (id)[UIColor colorWithWhite:0 alpha:dim].CGColor,
                     (id)[UIColor colorWithWhite:0 alpha:MIN(1, dim + 0.25)].CGColor];
    _wash.locations = @[@0, @0.5, @1];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _imageView.transform = CGAffineTransformIdentity;
    _imageView.frame = self.bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _wash.frame = self.bounds;
    [CATransaction commit];
}

- (void)showImageNamed:(NSString *)name animated:(BOOL)animated {
    if ([name isEqualToString:_name]) return;
    _name = name;
    [RTStyle loadImageNamed:name completion:^(UIImage *image) {
        if (![name isEqualToString:self->_name]) return;
        if (animated && !RTStyle.reduceMotion)
            [UIView transitionWithView:self->_imageView duration:0.6 options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{ self->_imageView.image = image; } completion:nil];
        else
            self->_imageView.image = image;
    }];
}

- (void)startDrift {
    if (RTStyle.reduceMotion) return;
    CABasicAnimation *zoom = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    zoom.fromValue = @1.0;
    zoom.toValue = @1.09;
    zoom.duration = 24;
    zoom.autoreverses = YES;
    zoom.repeatCount = HUGE_VALF;
    zoom.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    zoom.removedOnCompletion = NO;
    [_imageView.layer addAnimation:zoom forKey:@"drift"];
}
@end

@implementation RTTileButton

+ (instancetype)tileWithTitle:(NSString *)title color:(UIColor *)color {
    RTTileButton *b = [self buttonWithType:UIButtonTypeCustom];
    b.tileColor = color;
    [b setTitle:title forState:UIControlStateNormal];
    return b;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.titleLabel.font = [RTStyle stencil:28];
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        self.titleLabel.minimumScaleFactor = 0.5;
        self.titleLabel.numberOfLines = 2;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.shadowOffset = CGSizeMake(0, 2);
        [self setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.35] forState:UIControlStateNormal];
        [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.contentEdgeInsets = UIEdgeInsetsMake(6, 18, 6, 18);
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.55;
        self.layer.shadowRadius = 8;
        self.layer.shadowOffset = CGSizeMake(0, 5);
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
        self.layer.borderWidth = 2;
        self.exclusiveTouch = YES;
    }
    return self;
}

- (void)setTileColor:(UIColor *)tileColor {
    _tileColor = tileColor;
    self.backgroundColor = tileColor;
}

- (void)setTilt:(CGFloat)tilt {
    _tilt = tilt;
    [self applyTransform];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12 animations:^{ [self applyTransform]; }];
}

- (void)applyTransform {
    CGFloat s = self.highlighted ? 0.95 : 1;
    self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(_tilt), s, s);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
}
@end

@implementation RTPaperView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.6;
        self.layer.shadowRadius = 14;
        self.layer.shadowOffset = CGSizeMake(0, 8);
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect:CGRectInset(self.bounds, 0, 6)].CGPath;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect paper = CGRectInset(self.bounds, 0, 6);
    [RTStyle.paper setFill];
    CGContextFillRect(ctx, paper);
    // Faint ruled lines, like a page torn from a notebook.
    [[UIColor colorWithRed:0.55 green:0.68 blue:0.82 alpha:0.35] setFill];
    for (CGFloat y = paper.origin.y + 44; y < CGRectGetMaxY(paper) - 8; y += 32) CGContextFillRect(ctx, CGRectMake(paper.origin.x, y, paper.size.width, 1));
    [[UIColor colorWithRed:0.85 green:0.3 blue:0.3 alpha:0.4] setFill];
    CGContextFillRect(ctx, CGRectMake(paper.origin.x + 34, paper.origin.y, 1, paper.size.height));
    // Tape.
    for (int i = 0; i < 2; i++) {
        CGContextSaveGState(ctx);
        CGFloat x = i == 0 ? 54 : self.bounds.size.width - 54;
        CGContextTranslateCTM(ctx, x, 8);
        CGContextRotateCTM(ctx, i == 0 ? -0.18 : 0.15);
        [[UIColor colorWithRed:0.93 green:0.88 blue:0.72 alpha:0.78] setFill];
        CGContextFillRect(ctx, CGRectMake(-48, -13, 96, 26));
        CGContextRestoreGState(ctx);
    }
}
@end

@implementation RTPolaroidView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.whiteColor;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowRadius = 6;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        _imageView = [UIImageView new];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.backgroundColor = UIColor.darkGrayColor;
        [self addSubview:_imageView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat m = 10;
    _imageView.frame = CGRectMake(m, m, self.bounds.size.width - 2 * m, self.bounds.size.height - m - 30);
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
}
@end
