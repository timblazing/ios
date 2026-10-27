#import "Panel.h"
#import "Icons.h"
#import "Theme.h"

@implementation Panel {
    UIControl *_backdrop;
    UIView *_card;
    UILabel *_title;
    UIButton *_close;
    UIScrollView *_scroll;
    NSMutableArray<NSArray *> *_rows; // [view, spacing]
    NSMutableArray<UIView *> *_dividers;
    BOOL _closing;
}
- (instancetype)initWithStyle:(PanelStyle)style title:(NSString *)title {
    if (!(self = [super initWithFrame:CGRectZero]))
        return nil;
    _style = style;
    _rows = [NSMutableArray array];
    _dividers = [NSMutableArray array];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backdrop = [UIControl new];
    [_backdrop addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_backdrop];
    _card = [UIView new];
    [self addSubview:_card];
    _title = [UILabel new];
    _title.text = title.uppercaseString;
    _title.font = [Theme boldFontOfSize:16];
    _title.textAlignment = NSTextAlignmentCenter;
    _title.accessibilityTraits = UIAccessibilityTraitHeader;
    [_card addSubview:_title];
    _close = [UIButton buttonWithType:UIButtonTypeCustom];
    [_close setImage:Icon(@"close") forState:UIControlStateNormal];
    _close.accessibilityLabel = @"Close";
    [_close addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_close];
    _scroll = [UIScrollView new];
    _scroll.alwaysBounceVertical = style == PanelStylePage;
    [_card addSubview:_scroll];
    _contentView = [UIView new];
    [_scroll addSubview:_contentView];
    if (style == PanelStyleModal) {
        _card.layer.cornerRadius = 8;
        _card.layer.borderWidth = 1;
        _card.layer.shadowOpacity = 0.2;
        _card.layer.shadowRadius = 12;
        _card.layer.shadowOffset = CGSizeMake(0, 4);
    } else if (style == PanelStyleDrawer) {
        _card.layer.shadowOpacity = 0.15;
        _card.layer.shadowRadius = 10;
        _card.layer.shadowOffset = CGSizeMake(3, 0);
    }
    self.accessibilityViewIsModal = YES;
    [self applyTheme];
    return self;
}
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.numberOfLines = 0;
    return label;
}
- (UIView *)divider {
    UIView *line = [UIView new];
    line.bounds = CGRectMake(0, 0, 0, 1);
    [_dividers addObject:line];
    line.backgroundColor = [Theme emptyBorder];
    return line;
}
- (void)addRow:(UIView *)view spacing:(CGFloat)spacing {
    [_rows addObject:@[ view, @(spacing) ]];
    [_contentView addSubview:view];
}
- (CGFloat)layoutContentForWidth:(CGFloat)width {
    CGFloat y = 0;
    for (NSArray *row in _rows) {
        UIView *view = row[0];
        y += [row[1] doubleValue];
        CGFloat w = view.bounds.size.width > 0 && ![view isKindOfClass:[UILabel class]] ? view.bounds.size.width : width;
        CGFloat h = [view isKindOfClass:[UILabel class]] ? ceil([view sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height)
                                                          : view.bounds.size.height;
        view.frame = CGRectMake(0, y, w, h);
        y += h;
    }
    return y;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    _backdrop.frame = self.bounds;
    CGAffineTransform transform = _card.transform;
    _card.transform = CGAffineTransformIdentity;
    if (_style == PanelStylePage) {
        CGFloat width = MIN(500, size.width - 32), top = 56;
        _card.frame = self.bounds;
        _title.frame = CGRectMake(0, 0, size.width, top);
        _close.frame = CGRectMake((size.width + width) / 2 - 36, 6, 44, 44);
        CGFloat h = [self layoutContentForWidth:width];
        _scroll.frame = CGRectMake(0, top, size.width, size.height - top);
        _contentView.frame = CGRectMake(round((size.width - width) / 2), 8, width, h);
        _scroll.contentSize = CGSizeMake(size.width, h + 40);
    } else if (_style == PanelStyleModal) {
        CGFloat width = MIN(500, size.width - 32), inner = width - 32, top = 52;
        CGFloat h = [self layoutContentForWidth:inner];
        CGFloat cardHeight = MIN(top + h + 24, size.height - 32);
        _card.frame = CGRectMake(round((size.width - width) / 2), round((size.height - cardHeight) / 2), width, cardHeight);
        _title.frame = CGRectMake(0, 12, width, top - 12);
        _close.frame = CGRectMake(width - 48, 4, 44, 44);
        _scroll.frame = CGRectMake(16, top, inner, cardHeight - top - 8);
        _contentView.frame = CGRectMake(0, 4, inner, h);
        _scroll.contentSize = CGSizeMake(inner, h + 16);
    } else {
        CGFloat width = MIN(340, round(size.width * 0.8)), top = 56;
        _card.frame = CGRectMake(0, 0, width, size.height);
        _title.frame = CGRectMake(20, 0, width - 80, top);
        _title.textAlignment = NSTextAlignmentLeft;
        _close.frame = CGRectMake(width - 52, 6, 44, 44);
        CGFloat h = [self layoutContentForWidth:width];
        _scroll.frame = CGRectMake(0, top, width, size.height - top);
        _contentView.frame = CGRectMake(0, 0, width, h);
        _scroll.contentSize = CGSizeMake(width, h);
    }
    _card.layer.shadowPath = _style == PanelStylePage ? nil : [UIBezierPath bezierPathWithRoundedRect:_card.bounds cornerRadius:_card.layer.cornerRadius].CGPath;
    _card.transform = transform;
}
- (void)applyTheme {
    _backdrop.backgroundColor = _style == PanelStyleModal ? [Theme backdrop] : _style == PanelStyleDrawer ? [UIColor colorWithWhite:0 alpha:0.3] : [UIColor clearColor];
    _card.backgroundColor = [Theme background];
    _card.layer.borderColor = [Theme cardBorder].CGColor;
    _title.textColor = [Theme text];
    _close.tintColor = [Theme text];
    for (UIView *line in _dividers)
        line.backgroundColor = [Theme emptyBorder];
    for (NSArray *row in _rows)
        if ([row[0] isKindOfClass:[UILabel class]] && ![row[0] tag])
            ((UILabel *)row[0]).textColor = [Theme text];
}
- (CGAffineTransform)hiddenTransform {
    if (UIAccessibilityIsReduceMotionEnabled())
        return CGAffineTransformIdentity;
    return _style == PanelStyleDrawer ? CGAffineTransformMakeTranslation(-_card.bounds.size.width, 0)
                                      : CGAffineTransformMakeTranslation(0, 30);
}
- (void)showInView:(UIView *)view {
    self.frame = view.bounds;
    [view addSubview:self];
    [self layoutIfNeeded];
    _card.transform = [self hiddenTransform];
    _card.alpha = _style == PanelStyleDrawer ? 1 : 0;
    _backdrop.alpha = 0;
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self->_card.transform = CGAffineTransformIdentity;
                         self->_card.alpha = 1;
                         self->_backdrop.alpha = 1;
                     }
                     completion:nil];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _title);
}
- (void)dismiss {
    if (_closing)
        return;
    _closing = YES;
    self.userInteractionEnabled = NO;
    if (self.onClose)
        self.onClose();
    [UIView animateWithDuration:0.2
        delay:0
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
            self->_card.transform = [self hiddenTransform];
            self->_card.alpha = self->_style == PanelStyleDrawer ? 1 : 0;
            self->_backdrop.alpha = 0;
        }
        completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
}
@end
