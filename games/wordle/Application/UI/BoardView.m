#import "BoardView.h"

@implementation BoardView {
    NSArray<TileView *> *_tiles;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame]))
        return nil;
    NSMutableArray *tiles = [NSMutableArray array];
    for (NSUInteger i = 0; i < 30; i++) {
        TileView *tile = [TileView new];
        [self addSubview:tile];
        [tiles addObject:tile];
    }
    _tiles = tiles;
    _tileSize = 62;
    _gap = 5;
    return self;
}
- (TileView *)tileAtRow:(NSUInteger)row column:(NSUInteger)column {
    return _tiles[row * 5 + column];
}
- (CGSize)boardSize {
    return CGSizeMake(5 * _tileSize + 4 * _gap, 6 * _tileSize + 5 * _gap);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    // bounds and center rather than frame, so a flip's transform doesn't fight the layout
    for (NSUInteger i = 0; i < 30; i++) {
        TileView *tile = _tiles[i];
        tile.bounds = CGRectMake(0, 0, _tileSize, _tileSize);
        tile.center = CGPointMake((i % 5) * (_tileSize + _gap) + _tileSize / 2,
                                  (i / 5) * (_tileSize + _gap) + _tileSize / 2);
    }
}
- (void)reset {
    for (TileView *tile in _tiles) {
        [tile cancelAnimations];
        tile.letter = nil;
        tile.state = LetterStateNone;
    }
}
- (void)setLetters:(NSString *)letters inRow:(NSUInteger)row {
    for (NSUInteger c = 0; c < 5; c++)
        [self tileAtRow:row column:c].letter = c < letters.length ? [letters substringWithRange:NSMakeRange(c, 1)] : nil;
}
- (void)setStates:(NSArray<NSNumber *> *)states inRow:(NSUInteger)row {
    for (NSUInteger c = 0; c < 5; c++)
        [self tileAtRow:row column:c].state = c < states.count ? states[c].integerValue : LetterStateNone;
}
- (void)revealRow:(NSUInteger)row
           states:(NSArray<NSNumber *> *)states
         animated:(BOOL)animated
       completion:(void (^)(void))completion {
    if (!animated) {
        [self setStates:states inRow:row];
        if (completion)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(),
                           completion);
        return;
    }
    for (NSUInteger c = 0; c < 5; c++)
        [[self tileAtRow:row column:c] flipToState:states[c].integerValue
                                             delay:c * 0.3
                                        completion:c == 4 ? completion : nil];
}
- (void)bounceRow:(NSUInteger)row {
    for (NSUInteger c = 0; c < 5; c++)
        [[self tileAtRow:row column:c] bounceAfter:c * 0.1];
}
- (void)shakeRow:(NSUInteger)row {
    for (NSUInteger c = 0; c < 5; c++)
        [[self tileAtRow:row column:c] shake];
}
- (void)applyTheme {
    for (TileView *tile in _tiles)
        [tile applyTheme];
}
@end
