#import "TileView.h"
#import "Theme.h"

@implementation TileView {
    UILabel *_label;
    NSUInteger _generation;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame]))
        return nil;
    _label = [UILabel new];
    _label.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_label];
    self.layer.borderWidth = 2;
    self.isAccessibilityElement = YES;
    [self applyTheme];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _label.frame = self.bounds;
    CGFloat size = round(self.bounds.size.width * 0.52);
    if (_label.font.pointSize != size)
        _label.font = [Theme boldFontOfSize:size];
}
- (void)setLetter:(NSString *)letter {
    _letter = [letter copy];
    _label.text = letter;
    [self applyTheme];
}
- (void)setState:(LetterState)state {
    _state = state;
    [self applyTheme];
}
- (void)applyTheme {
    if (_state == LetterStateNone) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.borderColor = (_letter.length ? [Theme filledBorder] : [Theme emptyBorder]).CGColor;
        _label.textColor = [Theme text];
    } else {
        UIColor *color = [Theme colorForState:_state];
        self.backgroundColor = color;
        self.layer.borderColor = color.CGColor;
        _label.textColor = [UIColor whiteColor];
    }
    NSString *what = @[ @"", @"not in the word", @"in the wrong spot", @"correct" ][_state];
    self.accessibilityLabel = _letter.length ? [NSString stringWithFormat:@"%@ %@", _letter, what] : @"empty";
}
- (void)pop {
    CAKeyframeAnimation *pop = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    pop.values = @[ @0.8, @1.1, @1 ];
    pop.keyTimes = @[ @0, @0.4, @1 ];
    pop.duration = 0.1;
    [self.layer addAnimation:pop forKey:@"pop"];
}
- (void)flipToState:(LetterState)state delay:(NSTimeInterval)delay completion:(void (^)(void))completion {
    NSUInteger generation = ++_generation;
    // Wordle's rotateX has no perspective, so a vertical squash looks the same.
    [UIView animateWithDuration:0.25
        delay:delay
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
            self.transform = CGAffineTransformMakeScale(1, 0.01);
        }
        completion:^(BOOL finished) {
            if (generation != self->_generation)
                return;
            self.state = state;
            [UIView animateWithDuration:0.25
                delay:0
                options:UIViewAnimationOptionCurveEaseOut
                animations:^{
                    self.transform = CGAffineTransformIdentity;
                }
                completion:^(BOOL done) {
                    if (generation == self->_generation && completion)
                        completion();
                }];
        }];
}
- (void)bounceAfter:(NSTimeInterval)delay {
    CAKeyframeAnimation *bounce = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.y"];
    bounce.values = @[ @0, @0, @-30, @5, @-15, @2, @0 ];
    bounce.keyTimes = @[ @0, @0.2, @0.4, @0.5, @0.6, @0.8, @1 ];
    bounce.duration = 1;
    bounce.beginTime = CACurrentMediaTime() + delay;
    [self.layer addAnimation:bounce forKey:@"bounce"];
}
- (void)shake {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[ @0, @-1, @2, @-4, @4, @-4, @4, @-4, @2, @-1, @0 ];
    shake.duration = 0.6;
    [self.layer addAnimation:shake forKey:@"shake"];
}
- (void)cancelAnimations {
    _generation++;
    [self.layer removeAllAnimations];
    self.transform = CGAffineTransformIdentity;
}
@end
