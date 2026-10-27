#import "KeyboardView.h"
#import "Icons.h"
#import "Theme.h"

NSString *const KeyEnter = @"ENTER";
NSString *const KeyDelete = @"DELETE";
static const CGFloat KeyGap = 6, RowGap = 8;

@interface KeyButton : UIButton
@property(nonatomic, copy) NSString *key;
@end
@implementation KeyButton
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.7 : 1;
}
@end

@implementation KeyboardView {
    NSArray<NSArray<KeyButton *> *> *_rows;
    NSDictionary<NSString *, NSNumber *> *_states;
}
+ (CGFloat)heightForKeyHeight:(CGFloat)keyHeight {
    return 3 * keyHeight + 2 * RowGap;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame]))
        return nil;
    self.multipleTouchEnabled = YES;
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *letters in @[ @"QWERTYUIOP", @"ASDFGHJKL", @"ZXCVBNM" ]) {
        NSMutableArray *keys = [NSMutableArray array];
        for (NSUInteger i = 0; i < letters.length; i++)
            [keys addObject:[self keyFor:[letters substringWithRange:NSMakeRange(i, 1)]]];
        [rows addObject:keys];
    }
    [rows.lastObject insertObject:[self keyFor:KeyEnter] atIndex:0];
    [rows.lastObject addObject:[self keyFor:KeyDelete]];
    _rows = rows;
    [self applyTheme];
    return self;
}
- (KeyButton *)keyFor:(NSString *)key {
    KeyButton *button = [KeyButton buttonWithType:UIButtonTypeCustom];
    button.key = key;
    button.layer.cornerRadius = 4;
    button.exclusiveTouch = NO;
    if ([key isEqualToString:KeyDelete]) {
        [button setImage:Icon(@"backspace") forState:UIControlStateNormal];
        button.accessibilityLabel = @"Delete";
    } else {
        [button setTitle:key forState:UIControlStateNormal];
        button.titleLabel.font = [Theme boldFontOfSize:key.length > 1 ? 12 : 20];
        if (key.length > 1)
            button.accessibilityLabel = @"Enter";
    }
    [button addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:button];
    return button;
}
- (void)tapped:(KeyButton *)button {
    if (self.onKey)
        self.onKey(button.key);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    CGFloat keyHeight = (self.bounds.size.height - 2 * RowGap) / 3;
    CGFloat unit = (width - 9 * KeyGap) / 10;
    for (NSUInteger r = 0; r < 3; r++) {
        NSArray<KeyButton *> *keys = _rows[r];
        // The bottom row's wide keys take the leftover gap so its edges line up with the top row.
        CGFloat wide = 1.5 * unit + KeyGap / 2;
        CGFloat rowWidth = r == 2 ? width : keys.count * unit + (keys.count - 1) * KeyGap;
        CGFloat x = round((width - rowWidth) / 2), y = r * (keyHeight + RowGap);
        for (KeyButton *key in keys) {
            CGFloat w = key.key.length > 1 ? wide : unit;
            key.frame = CGRectMake(x, y, w, keyHeight);
            x += w + KeyGap;
        }
    }
}
- (void)setStates:(NSDictionary<NSString *, NSNumber *> *)states animated:(BOOL)animated {
    _states = [states copy];
    if (!animated) {
        [self applyTheme];
        return;
    }
    [UIView animateWithDuration:0.15
                     animations:^{
                         [self applyTheme];
                     }];
}
- (void)applyTheme {
    for (NSArray<KeyButton *> *row in _rows)
        for (KeyButton *key in row) {
            LetterState state = [_states[key.key] integerValue];
            key.backgroundColor = state ? [Theme colorForState:state] : [Theme key];
            UIColor *text = state ? [UIColor whiteColor] : [Theme keyText];
            [key setTitleColor:text forState:UIControlStateNormal];
            key.tintColor = text;
            NSString *what = @[ @"", @", not in the word", @", in the wrong spot", @", correct" ][state];
            if (key.key.length == 1)
                key.accessibilityLabel = [key.key stringByAppendingString:what];
        }
}
@end
