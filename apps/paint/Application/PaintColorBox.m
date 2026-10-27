#import "PaintColorBox.h"

NSString *PaintColorName(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 1, w = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a] && [color getWhite:&w alpha:&a]) r = g = b = w;
    return [NSString stringWithFormat:@"red %d, green %d, blue %d", (int)lround(r * 255), (int)lround(g * 255), (int)lround(b * 255)];
}

@interface PaintSwatch : UIControl
@property(nonatomic, strong) UIColor *color;
@end

@implementation PaintSwatch
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitButton; self.accessibilityHint = @"Sets color 1. Touch and hold to set color 2."; }
    return self;
}
- (void)setColor:(UIColor *)color { _color = color; self.accessibilityLabel = PaintColorName(color); [self setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGRect r = CGRectInset(self.bounds, 2, 2);
    [self.color setFill];
    UIRectFill(r);
    XPDrawBevel(r, NO, YES);
    if (self.highlighted) { [XPSelectionColor() setStroke]; UIBezierPath *p = [UIBezierPath bezierPathWithRect:CGRectInset(self.bounds, 1, 1)]; p.lineWidth = 2; [p stroke]; }
}
@end

// Color 1 sits over color 2, as in XP; tapping swaps them.
@interface PaintColorWell : UIControl
@property(nonatomic, strong) UIColor *primary, *secondary;
@end

@implementation PaintColorWell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitButton; self.accessibilityHint = @"Swaps color 1 and color 2."; }
    return self;
}
- (NSString *)accessibilityLabel { return [NSString stringWithFormat:@"Color 1 %@. Color 2 %@.", PaintColorName(self.primary), PaintColorName(self.secondary)]; }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGRect b = self.bounds;
    [XPColor(self.highlighted ? 0xD8D4C4 : 0xF5F4EE) setFill];
    UIRectFill(b);
    XPDrawBevel(b, NO, YES);
    CGFloat s = floor(b.size.width * .46);
    CGRect back = CGRectMake(b.size.width - s - 8, b.size.height - s - 8, s, s), front = CGRectMake(8, 8, s, s);
    for (NSInteger i = 0; i < 2; i++) {
        CGRect r = i ? front : back;
        [UIColor.whiteColor setFill]; UIRectFill(r);
        [(i ? self.primary : self.secondary) setFill]; UIRectFill(CGRectInset(r, 3, 3));
        XPDrawBevel(r, YES, YES);
    }
    // Swap arrow in the free corner.
    UIBezierPath *arrow = [UIBezierPath bezierPath];
    CGFloat x = b.size.width - 22, y = 9;
    [arrow moveToPoint:CGPointMake(x, y + 3)]; [arrow addQuadCurveToPoint:CGPointMake(x + 11, y + 12) controlPoint:CGPointMake(x + 11, y + 3)];
    [arrow moveToPoint:CGPointMake(x + 3, y)]; [arrow addLineToPoint:CGPointMake(x, y + 3)]; [arrow addLineToPoint:CGPointMake(x + 3, y + 6)];
    [arrow moveToPoint:CGPointMake(x + 8, y + 9)]; [arrow addLineToPoint:CGPointMake(x + 11, y + 12)]; [arrow addLineToPoint:CGPointMake(x + 14, y + 9)];
    arrow.lineWidth = 1.6; arrow.lineCapStyle = kCGLineCapRound; arrow.lineJoinStyle = kCGLineJoinRound;
    [XPColor(0x333333) setStroke]; [arrow stroke];
}
@end

@implementation PaintColorBox {
    PaintColorWell *_well;
    NSMutableArray<PaintSwatch *> *_swatches;
    XPButton *_edit;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _well = [PaintColorWell new];
        [_well addTarget:self action:@selector(swapTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_well];
        _swatches = [NSMutableArray array];
        _edit = [XPButton buttonWithTitle:@"Edit Colors…" target:self action:@selector(editTapped)];
        [self addSubview:_edit];
    }
    return self;
}

- (void)setColors:(NSArray<UIColor *> *)colors {
    _colors = [colors copy];
    while (_swatches.count < colors.count) {
        PaintSwatch *swatch = [PaintSwatch new];
        swatch.tag = (NSInteger)_swatches.count;
        [swatch addTarget:self action:@selector(swatchTapped:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(swatchHeld:)];
        hold.minimumPressDuration = .35;
        [swatch addGestureRecognizer:hold];
        [self addSubview:swatch];
        [_swatches addObject:swatch];
    }
    [self reload];
    [self setNeedsLayout];
}

- (void)reload {
    for (NSUInteger i = 0; i < _swatches.count; i++) _swatches[i].color = i < self.colors.count ? self.colors[i] : UIColor.whiteColor;
    _well.primary = self.primary;
    _well.secondary = self.secondary;
    [_well setNeedsDisplay];
}

- (void)swatchTapped:(PaintSwatch *)swatch { if (self.onPick) self.onPick((NSUInteger)swatch.tag, NO); }
- (void)swatchHeld:(UILongPressGestureRecognizer *)hold { if (hold.state == UIGestureRecognizerStateBegan && self.onPick) self.onPick((NSUInteger)hold.view.tag, YES); }
- (void)swapTapped { if (self.onSwap) self.onSwap(); }
- (void)editTapped { if (self.onEdit) self.onEdit(); }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height, w = self.bounds.size.width, wellSize = h - 14;
    _well.frame = CGRectMake(8, 7, wellSize, wellSize);
    CGFloat editW = 134, left = 8 + wellSize + 10, right = w - editW - 16;
    NSUInteger columns = (_swatches.count + 1) / 2;
    CGFloat cellW = MIN(46, floor((right - left) / MAX(1, columns))), cellH = floor((h - 10) / 2);
    for (NSUInteger i = 0; i < _swatches.count; i++) _swatches[i].frame = CGRectMake(left + (i % columns) * cellW, 5 + (i / columns) * cellH, cellW, cellH);
    _edit.frame = CGRectMake(left + columns * cellW + 10, round((h - 44) / 2), editW, 44);
}
@end
