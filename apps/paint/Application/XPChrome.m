#import "XPChrome.h"
#import <objc/runtime.h>

UIColor *XPColor(uint32_t rgb) { return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0 blue:(rgb & 0xff) / 255.0 alpha:1]; }
UIColor *XPFaceColor(void) { return XPColor(0xECE9D8); }
UIColor *XPSelectionColor(void) { return XPColor(0x316AC5); }
// iOS has no Tahoma; Verdana is its wider sibling. XP title bars used Trebuchet MS Bold.
UIFont *XPFont(CGFloat size) { return [UIFont fontWithName:@"Verdana" size:size] ?: [UIFont systemFontOfSize:size]; }
UIFont *XPBoldFont(CGFloat size) { return [UIFont fontWithName:@"Verdana-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size]; }
UIFont *XPTitleFont(CGFloat size) { return [UIFont fontWithName:@"TrebuchetMS-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size]; }

UIImage *PaintIcon(NSString *name) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; });
    UIImage *image = [cache objectForKey:name];
    if (!image) {
        NSString *path = [[NSBundle mainBundle] pathForResource:[name stringByAppendingString:@"@2x"] ofType:@"png" inDirectory:@"Icons"];
        NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
        image = data ? [UIImage imageWithData:data scale:2] : nil;
        if (image) [cache setObject:image forKey:name];
    }
    return image;
}

void XPNoAnimation(void (^block)(void)) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    block();
    [CATransaction commit];
}

static void XPLine(CGContextRef c, CGPoint a, CGPoint b, UIColor *color) {
    [color setStroke];
    CGContextSetLineWidth(c, 1);
    CGContextMoveToPoint(c, a.x, a.y);
    CGContextAddLineToPoint(c, b.x, b.y);
    CGContextStrokePath(c);
}

// Classic two-pixel 3D edge: light top-left, dark bottom-right (swapped when sunken).
void XPDrawBevel(CGRect rect, BOOL raised, BOOL thick) {
    CGContextRef c = UIGraphicsGetCurrentContext();
    UIColor *outerLight = raised ? UIColor.whiteColor : XPColor(0xACA899), *outerDark = raised ? XPColor(0x716F64) : UIColor.whiteColor;
    UIColor *innerLight = raised ? XPColor(0xF5F4EE) : XPColor(0x716F64), *innerDark = raised ? XPColor(0xACA899) : XPColor(0xF5F4EE);
    CGRect r = CGRectInset(rect, .5, .5);
    CGFloat x0 = CGRectGetMinX(r), y0 = CGRectGetMinY(r), x1 = CGRectGetMaxX(r), y1 = CGRectGetMaxY(r);
    XPLine(c, CGPointMake(x0, y1), CGPointMake(x0, y0), outerLight);
    XPLine(c, CGPointMake(x0, y0), CGPointMake(x1, y0), outerLight);
    XPLine(c, CGPointMake(x1, y0), CGPointMake(x1, y1), outerDark);
    XPLine(c, CGPointMake(x1, y1), CGPointMake(x0, y1), outerDark);
    if (!thick) return;
    r = CGRectInset(r, 1, 1);
    x0 = CGRectGetMinX(r); y0 = CGRectGetMinY(r); x1 = CGRectGetMaxX(r); y1 = CGRectGetMaxY(r);
    XPLine(c, CGPointMake(x0, y1), CGPointMake(x0, y0), innerLight);
    XPLine(c, CGPointMake(x0, y0), CGPointMake(x1, y0), innerLight);
    XPLine(c, CGPointMake(x1, y0), CGPointMake(x1, y1), innerDark);
    XPLine(c, CGPointMake(x1, y1), CGPointMake(x0, y1), innerDark);
}

static UIColor *XPDitherColor(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(2, 2), YES, 2);
        [UIColor.whiteColor setFill]; UIRectFill(CGRectMake(0, 0, 2, 2));
        [XPColor(0xD8D4C4) setFill]; UIRectFill(CGRectMake(0, 0, 1, 1)); UIRectFill(CGRectMake(1, 1, 1, 1));
        color = [UIColor colorWithPatternImage:UIGraphicsGetImageFromCurrentImageContext()];
        UIGraphicsEndImageContext();
    });
    return color;
}

@implementation XPPanel
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = XPFaceColor(); self.contentMode = UIViewContentModeRedraw; }
    return self;
}
- (void)drawRect:(CGRect)rect { XPDrawBevel(self.bounds, !self.sunken, self.thick); }
@end

@implementation XPTitleGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        CAGradientLayer *g = (CAGradientLayer *)self.layer;
        g.colors = @[(id)XPColor(0x3D95FF).CGColor, (id)XPColor(0x0A63EC).CGColor, (id)XPColor(0x0055E5).CGColor, (id)XPColor(0x0052E0).CGColor, (id)XPColor(0x0040B8).CGColor];
        g.locations = @[@0, @.12, @.5, @.85, @1];
    }
    return self;
}
@end

@implementation XPToolButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitButton; }
    return self;
}
- (void)setSelected:(BOOL)selected { [super setSelected:selected]; [self setNeedsDisplay]; self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0); }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    BOOL down = self.selected || self.highlighted;
    [(self.selected ? XPDitherColor() : XPFaceColor()) setFill];
    UIRectFill(self.bounds);
    XPDrawBevel(self.bounds, !down, YES);
    CGSize s = self.icon.size;
    CGFloat nudge = down ? 1 : 0;
    [self.icon drawInRect:CGRectMake(round((self.bounds.size.width - s.width) / 2) + nudge, round((self.bounds.size.height - s.height) / 2) + nudge, s.width, s.height)];
}
@end

@implementation XPButton
+ (instancetype)buttonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
    XPButton *button = [[self alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
    button.title = title;
    if (target) [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitButton; }
    return self;
}
- (void)setTitle:(NSString *)title { _title = [title copy]; self.accessibilityLabel = title; [self setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self setNeedsDisplay]; }
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect r = CGRectInset(self.bounds, 1, 1);
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:4];
    CGContextSaveGState(c);
    [shape addClip];
    NSArray *colors = self.highlighted ? @[(id)XPColor(0xCDCAC3).CGColor, (id)XPColor(0xE3E2DA).CGColor, (id)XPColor(0xF0F0EA).CGColor]
                                       : @[(id)UIColor.whiteColor.CGColor, (id)XPColor(0xF3F3EF).CGColor, (id)XPColor(0xD6D0C5).CGColor];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[3] = {0, .55, 1};
    CGGradientRef g = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(c);
    if (self.isDefault && !self.highlighted) {
        UIBezierPath *glow = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(r, 1.5, 1.5) cornerRadius:3];
        glow.lineWidth = 2; [XPColor(0x8CB4F2) setStroke]; [glow stroke];
    }
    shape.lineWidth = 1; [(self.enabled ? XPColor(0x003C74) : XPColor(0xC9C7BA)) setStroke]; [shape stroke];
    NSDictionary *attrs = @{NSFontAttributeName: XPFont(14), NSForegroundColorAttributeName: self.enabled ? UIColor.blackColor : XPColor(0xACA899)};
    CGSize s = [self.title sizeWithAttributes:attrs];
    [self.title drawAtPoint:CGPointMake(round((self.bounds.size.width - s.width) / 2), round((self.bounds.size.height - s.height) / 2)) withAttributes:attrs];
}
@end

@implementation XPFlatButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitButton; }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self setNeedsDisplay]; }
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; self.alpha = enabled ? 1 : .45; }
- (void)setLit:(BOOL)lit { _lit = lit; [self setNeedsDisplay]; }
- (void)setTitle:(NSString *)title { _title = [title copy]; if (!self.accessibilityLabel) self.accessibilityLabel = title; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    BOOL on = self.highlighted || self.lit;
    if (on) {
        [(self.highlightColor ?: XPSelectionColor()) setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 1, 3) cornerRadius:3] fill];
    }
    if (self.icon) {
        CGSize s = self.icon.size;
        [self.icon drawInRect:CGRectMake(round((self.bounds.size.width - s.width) / 2), round((self.bounds.size.height - s.height) / 2), s.width, s.height)];
    }
    if (self.title) {
        NSDictionary *attrs = @{NSFontAttributeName: XPFont(15), NSForegroundColorAttributeName: on ? UIColor.whiteColor : UIColor.blackColor};
        CGSize s = [self.title sizeWithAttributes:attrs];
        [self.title drawAtPoint:CGPointMake(round((self.bounds.size.width - s.width) / 2), round((self.bounds.size.height - s.height) / 2)) withAttributes:attrs];
    }
}
@end

static const CGFloat XPWindowTitleHeight = 34, XPWindowBorder = 4;

@implementation XPWindow {
    UIView *_overlay;
    UILabel *_titleLabel;
}
- (instancetype)initWithTitle:(NSString *)title contentSize:(CGSize)size {
    CGRect frame = CGRectMake(0, 0, size.width + XPWindowBorder * 2, size.height + XPWindowTitleHeight + XPWindowBorder);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = XPColor(0x0831D9);
        self.layer.cornerRadius = 8;
        self.layer.shadowColor = UIColor.blackColor.CGColor; self.layer.shadowOpacity = .45; self.layer.shadowRadius = 10; self.layer.shadowOffset = CGSizeMake(0, 6);
        self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:8].CGPath;
        XPTitleGradientView *bar = [[XPTitleGradientView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, XPWindowTitleHeight + 6)];
        bar.layer.cornerRadius = 8; bar.layer.masksToBounds = YES;
        [self addSubview:bar];
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, frame.size.width - 60, XPWindowTitleHeight)];
        _titleLabel.text = title; _titleLabel.font = XPTitleFont(16); _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.shadowColor = XPColor(0x0A1E5A); _titleLabel.shadowOffset = CGSizeMake(1, 1);
        [self addSubview:_titleLabel];
        XPFlatButton *close = [[XPFlatButton alloc] initWithFrame:CGRectMake(frame.size.width - 44, 0, 44, XPWindowTitleHeight)];
        close.icon = PaintIcon(@"win-close"); close.highlightColor = UIColor.clearColor; close.accessibilityLabel = @"Close";
        [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:close];
        _contentView = [[UIView alloc] initWithFrame:CGRectMake(XPWindowBorder, XPWindowTitleHeight, size.width, size.height)];
        _contentView.backgroundColor = XPFaceColor();
        [self addSubview:_contentView];
    }
    return self;
}
- (void)closeTapped { void (^handler)(void) = self.onClose; [self dismiss]; if (handler) handler(); }
- (void)presentInView:(UIView *)host {
    _overlay = [[UIView alloc] initWithFrame:host.bounds];
    _overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.22];
    [host addSubview:_overlay];
    self.center = CGPointMake(round(host.bounds.size.width / 2), round(host.bounds.size.height / 2));
    self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [_overlay addSubview:self];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        _overlay.alpha = 0; self.transform = CGAffineTransformMakeScale(.94, .94);
        [UIView animateWithDuration:.16 animations:^{ self->_overlay.alpha = 1; self.transform = CGAffineTransformIdentity; }];
    }
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _titleLabel);
}
- (void)dismiss { [_overlay removeFromSuperview]; _overlay = nil; }
@end

static char XPHandlerKey;
static void XPSetHandler(XPWindow *window, void (^handler)(NSInteger)) { objc_setAssociatedObject(window, &XPHandlerKey, handler, OBJC_ASSOCIATION_COPY_NONATOMIC); }
static void (^XPHandler(XPWindow *window))(NSInteger) { return objc_getAssociatedObject(window, &XPHandlerKey); }

@implementation XPDialog
+ (XPWindow *)showInView:(UIView *)host title:(NSString *)title message:(NSString *)message icon:(XPDialogIcon)icon buttons:(NSArray<NSString *> *)buttons handler:(void (^)(NSInteger index))handler {
    CGFloat width = MAX(440, buttons.count * 114 + 30), iconSpace = icon == XPDialogIconNone ? 0 : 56;
    UIFont *font = XPFont(14);
    CGRect textRect = [message boundingRectWithSize:CGSizeMake(width - 40 - iconSpace, 400) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: font} context:nil];
    CGFloat textH = MAX(ceil(textRect.size.height), iconSpace ? 40 : 0);
    XPWindow *window = [[XPWindow alloc] initWithTitle:title contentSize:CGSizeMake(width, textH + 104)];
    UIView *content = window.contentView;
    if (icon != XPDialogIconNone) {
        NSString *name = icon == XPDialogIconInfo ? @"dlg-info" : icon == XPDialogIconWarning ? @"dlg-warning" : @"dlg-question";
        UIImageView *iv = [[UIImageView alloc] initWithImage:PaintIcon(name)];
        iv.frame = CGRectMake(20, 22, 34, 34);
        [content addSubview:iv];
    }
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20 + iconSpace, 22, width - 40 - iconSpace, textH)];
    label.text = message; label.font = font; label.numberOfLines = 0; label.textColor = UIColor.blackColor;
    [content addSubview:label];
    CGFloat bw = 104, gap = 10, total = buttons.count * bw + (buttons.count - 1) * gap, x = round((width - total) / 2);
    __weak XPWindow *weakWindow = window;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        XPButton *button = [XPButton buttonWithTitle:buttons[i] target:nil action:nil];
        button.frame = CGRectMake(x + i * (bw + gap), textH + 46, bw, 40);
        button.isDefault = i == 0;
        button.tag = (NSInteger)i;
        [button addTarget:[XPDialog class] action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [content addSubview:button];
    }
    XPSetHandler(window, ^(NSInteger index) { [weakWindow dismiss]; if (handler) handler(index); });
    NSInteger last = (NSInteger)buttons.count - 1;
    window.onClose = ^{ if (handler) handler(last); };
    [window presentInView:host];
    return window;
}
+ (void)buttonTapped:(XPButton *)button {
    UIView *view = button;
    while (view && ![view isKindOfClass:[XPWindow class]]) view = view.superview;
    void (^handler)(NSInteger) = XPHandler((XPWindow *)view);
    if (handler) handler(button.tag);
}
@end

@implementation XPMenuItem
+ (instancetype)item:(NSString *)title shortcut:(NSString *)shortcut action:(void (^)(void))action { return [self item:title shortcut:shortcut enabled:YES checked:NO action:action]; }
+ (instancetype)item:(NSString *)title shortcut:(NSString *)shortcut enabled:(BOOL)enabled checked:(BOOL)checked action:(void (^)(void))action {
    XPMenuItem *item = [self new];
    item.title = title; item.shortcut = shortcut; item.enabled = enabled; item.checked = checked; item.action = action;
    return item;
}
+ (instancetype)separator { XPMenuItem *item = [self new]; item.separator = YES; return item; }
@end

@interface XPMenuRow : UIControl
@property(nonatomic, strong) XPMenuItem *item;
@end

@implementation XPMenuRow
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.isAccessibilityElement = YES; }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    XPMenuItem *item = self.item;
    if (item.separator) {
        [XPColor(0xACA899) setFill];
        UIRectFill(CGRectMake(3, round(self.bounds.size.height / 2), self.bounds.size.width - 6, 1));
        return;
    }
    BOOL lit = self.highlighted && item.enabled;
    if (lit) { [XPSelectionColor() setFill]; UIRectFill(CGRectInset(self.bounds, 2, 1)); }
    UIColor *ink = !item.enabled ? XPColor(0xACA899) : lit ? UIColor.whiteColor : UIColor.blackColor;
    NSDictionary *attrs = @{NSFontAttributeName: XPFont(15), NSForegroundColorAttributeName: ink};
    CGFloat h = self.bounds.size.height, ty = round((h - XPFont(15).lineHeight) / 2);
    [item.title drawAtPoint:CGPointMake(32, ty) withAttributes:attrs];
    if (item.shortcut) {
        CGSize s = [item.shortcut sizeWithAttributes:attrs];
        [item.shortcut drawAtPoint:CGPointMake(self.bounds.size.width - s.width - 18, ty) withAttributes:attrs];
    }
    if (item.checked) {
        UIBezierPath *tick = [UIBezierPath bezierPath];
        [tick moveToPoint:CGPointMake(11, h / 2)]; [tick addLineToPoint:CGPointMake(15, h / 2 + 4)]; [tick addLineToPoint:CGPointMake(22, h / 2 - 5)];
        tick.lineWidth = 2.2; tick.lineCapStyle = kCGLineCapRound; tick.lineJoinStyle = kCGLineJoinRound;
        [ink setStroke]; [tick stroke];
    }
}
@end

@implementation XPMenuView
- (instancetype)initWithItems:(NSArray<XPMenuItem *> *)items {
    CGFloat width = 250;
    NSDictionary *attrs = @{NSFontAttributeName: XPFont(15)};
    for (XPMenuItem *item in items) {
        if (item.separator) continue;
        CGFloat w = 32 + [item.title sizeWithAttributes:attrs].width + (item.shortcut ? [item.shortcut sizeWithAttributes:attrs].width + 48 : 24);
        width = MAX(width, ceil(w));
    }
    CGFloat y = 3;
    NSMutableArray *rows = [NSMutableArray array];
    for (XPMenuItem *item in items) {
        CGFloat h = item.separator ? 11 : 44;
        XPMenuRow *row = [[XPMenuRow alloc] initWithFrame:CGRectMake(1, y, width - 2, h)];
        row.item = item;
        row.enabled = !item.separator && item.enabled;
        row.accessibilityLabel = item.title;
        row.accessibilityTraits = UIAccessibilityTraitButton | (item.checked ? UIAccessibilityTraitSelected : 0) | (row.enabled ? 0 : UIAccessibilityTraitNotEnabled);
        row.isAccessibilityElement = !item.separator;
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [rows addObject:row];
        y += h;
    }
    if ((self = [super initWithFrame:CGRectMake(0, 0, width, y + 3)])) {
        self.backgroundColor = UIColor.whiteColor;
        self.layer.borderColor = XPColor(0xACA899).CGColor; self.layer.borderWidth = 1;
        self.layer.shadowColor = UIColor.blackColor.CGColor; self.layer.shadowOpacity = .35; self.layer.shadowOffset = CGSizeMake(3, 3); self.layer.shadowRadius = 2;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
        for (UIView *row in rows) [self addSubview:row];
    }
    return self;
}
- (void)rowTapped:(XPMenuRow *)row { if (self.onPick) self.onPick(row.item); }
@end
