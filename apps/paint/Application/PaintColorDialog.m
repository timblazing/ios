#import "PaintColorDialog.h"
#import "PaintColorBox.h"

static CGFloat PaintHueToRGB(CGFloat p, CGFloat q, CGFloat t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1.0 / 6) return p + (q - p) * 6 * t;
    if (t < .5) return q;
    if (t < 2.0 / 3) return p + (q - p) * (2.0 / 3 - t) * 6;
    return p;
}

static void PaintHSLToRGB(CGFloat h, CGFloat s, CGFloat l, CGFloat *r, CGFloat *g, CGFloat *b) {
    if (s <= 0) { *r = *g = *b = l; return; }
    CGFloat q = l < .5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    *r = PaintHueToRGB(p, q, h + 1.0 / 3); *g = PaintHueToRGB(p, q, h); *b = PaintHueToRGB(p, q, h - 1.0 / 3);
}

static void PaintRGBToHSL(CGFloat r, CGFloat g, CGFloat b, CGFloat *h, CGFloat *s, CGFloat *l) {
    CGFloat mx = MAX(r, MAX(g, b)), mn = MIN(r, MIN(g, b));
    *l = (mx + mn) / 2;
    if (mx == mn) { *h = *s = 0; return; }
    CGFloat d = mx - mn;
    *s = *l > .5 ? d / (2 - mx - mn) : d / (mx + mn);
    if (mx == r) *h = (g - b) / d + (g < b ? 6 : 0);
    else if (mx == g) *h = (b - r) / d + 2;
    else *h = (r - g) / d + 4;
    *h /= 6;
}

static UIColor *PaintHSLColor(CGFloat h, CGFloat s, CGFloat l) {
    CGFloat r, g, b;
    PaintHSLToRGB(h, s, l, &r, &g, &b);
    return [UIColor colorWithRed:r green:g blue:b alpha:1];
}

@interface PaintColorEditor : UIView
@property(nonatomic) CGFloat hue, sat, lum;
@property(nonatomic, copy) void (^onDone)(UIColor *color);
@end

@implementation PaintColorEditor {
    UIImageView *_spectrum;
    UIView *_lumBar, *_preview;
    CAShapeLayer *_cross, *_arrow;
    CAGradientLayer *_lumGradient;
    UILabel *_values;
}

static const CGFloat kFieldX = 330, kFieldY = 36, kFieldW = 220, kFieldH = 184, kLumX = 564, kLumW = 22;

+ (NSArray<NSNumber *> *)basicColors {
    return @[@0xFF8080, @0xFFFF80, @0x80FF80, @0x00FF80, @0x80FFFF, @0x0080FF, @0xFF80C0, @0xFF80FF,
             @0xFF0000, @0xFFFF00, @0x80FF00, @0x00FF40, @0x00FFFF, @0x0080C0, @0x8080C0, @0xFF00FF,
             @0x804040, @0xFF8040, @0x00FF00, @0x008080, @0x004080, @0x8080FF, @0x800040, @0xFF0080,
             @0x800000, @0xFF8000, @0x008000, @0x008040, @0x0000FF, @0x0000A0, @0x800080, @0x8000FF,
             @0x400000, @0x804000, @0x004000, @0x004040, @0x000080, @0x000040, @0x400040, @0x400080,
             @0x000000, @0x808000, @0x808040, @0x808080, @0x408080, @0xC0C0C0, @0x404040, @0xFFFFFF];
}

+ (UIImage *)spectrumImage {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        int w = (int)kFieldW * 2, h = (int)kFieldH * 2;
        NSMutableData *data = [NSMutableData dataWithLength:(size_t)w * h * 4];
        uint8_t *px = data.mutableBytes;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            CGFloat r, g, b;
            PaintHSLToRGB((CGFloat)x / w, 1 - (CGFloat)y / h, .5, &r, &g, &b);
            uint8_t *p = px + ((size_t)y * w + x) * 4;
            p[0] = (uint8_t)lround(r * 255); p[1] = (uint8_t)lround(g * 255); p[2] = (uint8_t)lround(b * 255); p[3] = 255;
        }
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        CGImageRef cg = CGImageCreate(w, h, 8, 32, (size_t)w * 4, space, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
        image = [UIImage imageWithCGImage:cg scale:2 orientation:UIImageOrientationUp];
        CGImageRelease(cg);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(space);
    });
    return image;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        UILabel *basic = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, 280, 22)];
        basic.text = @"Basic colors:"; basic.font = XPFont(13);
        [self addSubview:basic];
        NSArray *colors = [PaintColorEditor basicColors];
        for (NSUInteger i = 0; i < colors.count; i++) {
            UIButton *swatch = [UIButton buttonWithType:UIButtonTypeCustom];
            swatch.frame = CGRectMake(16 + (i % 8) * 37, kFieldY + (i / 8) * 31, 33, 27);
            swatch.backgroundColor = XPColor([colors[i] unsignedIntValue]);
            swatch.layer.borderColor = XPColor(0x716F64).CGColor; swatch.layer.borderWidth = 1;
            swatch.tag = (NSInteger)i;
            swatch.accessibilityLabel = PaintColorName(swatch.backgroundColor);
            [swatch addTarget:self action:@selector(basicTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:swatch];
        }
        _spectrum = [[UIImageView alloc] initWithFrame:CGRectMake(kFieldX, kFieldY, kFieldW, kFieldH)];
        _spectrum.image = [PaintColorEditor spectrumImage];
        _spectrum.userInteractionEnabled = YES;
        _spectrum.layer.borderColor = XPColor(0x716F64).CGColor; _spectrum.layer.borderWidth = 1;
        _spectrum.isAccessibilityElement = YES; _spectrum.accessibilityLabel = @"Hue and saturation";
        [_spectrum addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(fieldTouched:)]];
        [_spectrum addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fieldTouched:)]];
        [self addSubview:_spectrum];
        _cross = [CAShapeLayer layer];
        _cross.strokeColor = UIColor.blackColor.CGColor; _cross.lineWidth = 2; _cross.fillColor = nil;
        [_spectrum.layer addSublayer:_cross];

        _lumBar = [[UIView alloc] initWithFrame:CGRectMake(kLumX, kFieldY, kLumW, kFieldH)];
        _lumBar.layer.borderColor = XPColor(0x716F64).CGColor; _lumBar.layer.borderWidth = 1;
        _lumGradient = [CAGradientLayer layer];
        _lumGradient.frame = _lumBar.bounds;
        [_lumBar.layer addSublayer:_lumGradient];
        [self addSubview:_lumBar];
        // A wider invisible strip so the thin bar is easy to drag.
        UIView *lumTouch = [[UIView alloc] initWithFrame:CGRectMake(kLumX - 12, kFieldY - 8, kLumW + 40, kFieldH + 16)];
        lumTouch.isAccessibilityElement = YES; lumTouch.accessibilityLabel = @"Luminosity";
        [lumTouch addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(lumTouched:)]];
        [lumTouch addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lumTouched:)]];
        [self addSubview:lumTouch];
        _arrow = [CAShapeLayer layer];
        _arrow.fillColor = UIColor.blackColor.CGColor;
        [self.layer addSublayer:_arrow];

        _preview = [[UIView alloc] initWithFrame:CGRectMake(kFieldX, kFieldY + kFieldH + 14, 96, 54)];
        _preview.layer.borderColor = XPColor(0x716F64).CGColor; _preview.layer.borderWidth = 1;
        [self addSubview:_preview];
        UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(kFieldX, kFieldY + kFieldH + 70, 96, 18)];
        caption.text = @"Color|Solid"; caption.font = XPFont(11); caption.textAlignment = NSTextAlignmentCenter;
        [self addSubview:caption];
        _values = [[UILabel alloc] initWithFrame:CGRectMake(kFieldX + 108, kFieldY + kFieldH + 12, 160, 80)];
        _values.numberOfLines = 0; _values.font = XPFont(12);
        [self addSubview:_values];

        XPButton *ok = [XPButton buttonWithTitle:@"OK" target:self action:@selector(okTapped)];
        ok.isDefault = YES;
        ok.frame = CGRectMake(16, frame.size.height - 58, 132, 42);
        [self addSubview:ok];
        XPButton *cancel = [XPButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelTapped)];
        cancel.frame = CGRectMake(160, frame.size.height - 58, 132, 42);
        [self addSubview:cancel];
    }
    return self;
}

- (UIColor *)color { return PaintHSLColor(self.hue, self.sat, self.lum); }

- (void)setColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 1, w = 0, h, s, l;
    if (![color getRed:&r green:&g blue:&b alpha:&a] && [color getWhite:&w alpha:&a]) r = g = b = w;
    PaintRGBToHSL(r, g, b, &h, &s, &l);
    _hue = h; _sat = s; _lum = l;
    [self update];
}

- (void)update {
    XPNoAnimation(^{
        CGFloat x = self.hue * kFieldW, y = (1 - self.sat) * kFieldH;
        UIBezierPath *cross = [UIBezierPath bezierPath];
        [cross moveToPoint:CGPointMake(x - 9, y)]; [cross addLineToPoint:CGPointMake(x - 3, y)];
        [cross moveToPoint:CGPointMake(x + 3, y)]; [cross addLineToPoint:CGPointMake(x + 9, y)];
        [cross moveToPoint:CGPointMake(x, y - 9)]; [cross addLineToPoint:CGPointMake(x, y - 3)];
        [cross moveToPoint:CGPointMake(x, y + 3)]; [cross addLineToPoint:CGPointMake(x, y + 9)];
        self->_cross.path = cross.CGPath;
        self->_lumGradient.colors = @[(id)PaintHSLColor(self.hue, self.sat, 1).CGColor, (id)PaintHSLColor(self.hue, self.sat, .5).CGColor, (id)PaintHSLColor(self.hue, self.sat, 0).CGColor];
        CGFloat ay = kFieldY + (1 - self.lum) * kFieldH, ax = kLumX + kLumW + 4;
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(ax, ay)]; [arrow addLineToPoint:CGPointMake(ax + 10, ay - 7)]; [arrow addLineToPoint:CGPointMake(ax + 10, ay + 7)]; [arrow closePath];
        self->_arrow.path = arrow.CGPath;
    });
    UIColor *color = [self color];
    _preview.backgroundColor = color;
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    // Windows shows hue, saturation, and luminosity on a 0-240 scale.
    _values.text = [NSString stringWithFormat:@"Hue: %d   Red: %d\nSat: %d   Green: %d\nLum: %d   Blue: %d\n#%02X%02X%02X",
                    (int)lround(self.hue * 239), (int)lround(r * 255), (int)lround(self.sat * 240), (int)lround(g * 255), (int)lround(self.lum * 240), (int)lround(b * 255),
                    (int)lround(r * 255), (int)lround(g * 255), (int)lround(b * 255)];
}

- (void)basicTapped:(UIButton *)button { [self setColor:button.backgroundColor]; }

- (void)fieldTouched:(UIGestureRecognizer *)gesture {
    CGPoint p = [gesture locationInView:_spectrum];
    _hue = MIN(MAX(p.x / kFieldW, 0), 1);
    _sat = 1 - MIN(MAX(p.y / kFieldH, 0), 1);
    // Picking from the field implies a pure color, as in Windows.
    if (gesture.state == UIGestureRecognizerStateBegan || [gesture isKindOfClass:[UITapGestureRecognizer class]]) if (_lum <= .02 || _lum >= .98) _lum = .5;
    [self update];
}

- (void)lumTouched:(UIGestureRecognizer *)gesture {
    CGPoint p = [gesture locationInView:_lumBar];
    _lum = 1 - MIN(MAX(p.y / kFieldH, 0), 1);
    [self update];
}

- (void)okTapped { if (self.onDone) self.onDone([self color]); }
- (void)cancelTapped { if (self.onDone) self.onDone(nil); }
@end

@implementation PaintColorDialog
+ (void)showInView:(UIView *)host color:(UIColor *)color completion:(void (^)(UIColor *color))completion {
    XPWindow *window = [[XPWindow alloc] initWithTitle:@"Edit Colors" contentSize:CGSizeMake(620, 380)];
    PaintColorEditor *editor = [[PaintColorEditor alloc] initWithFrame:window.contentView.bounds];
    [editor setColor:color];
    __weak XPWindow *weakWindow = window;
    editor.onDone = ^(UIColor *picked) { [weakWindow dismiss]; if (picked && completion) completion(picked); };
    [window.contentView addSubview:editor];
    [window presentInView:host];
}
@end
