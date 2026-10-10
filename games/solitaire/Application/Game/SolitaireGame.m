#import "SolitaireGame.h"
#import "Deck.h"
@interface SolitaireGame ()
@property(nonatomic, strong) NSArray<NSMutableArray<Card *> *> *piles;
@property(nonatomic) NSInteger moves;
@property(nonatomic, strong) NSMutableArray *history;
@property(nonatomic, strong) NSDate *started;
@property(nonatomic) NSTimeInterval frozenTime;
@end
@implementation SolitaireGame
- (instancetype)init {
    if ((self = [super init])) {
        _history = [NSMutableArray array];
        NSDictionary *state = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"savedGame"];
        if (![self restore:state])
            [self newGame];
    }
    return self;
}
- (BOOL)won {
    for (NSInteger i = 2; i < 6; i++)
        if (self.piles[i].count != 13)
            return NO;
    return YES;
}
- (BOOL)canUndo {
    return self.history.count > 0 && !self.won;
}
- (BOOL)canAutoWin {
    if (self.won)
        return NO;
    for (NSInteger p = 6; p < 13; p++)
        for (Card *c in self.piles[p])
            if (!c.faceUp)
                return NO;
    return YES;
}
- (NSTimeInterval)elapsed {
    return self.frozenTime >= 0 ? self.frozenTime : -[self.started timeIntervalSinceNow];
}
- (NSDictionary *)snapshot {
    NSMutableArray *piles = [NSMutableArray array];
    for (NSArray *pile in self.piles) {
        NSMutableArray *cards = [NSMutableArray array];
        for (Card *c in pile)
            [cards addObject:@[ @(c.identifier), @(c.faceUp) ]];
        [piles addObject:cards];
    }
    return @{@"piles" : piles, @"moves" : @(self.moves), @"elapsed" : @(self.elapsed), @"version" : @1};
}
- (BOOL)restore:(NSDictionary *)state {
    if (![state isKindOfClass:[NSDictionary class]] || ![state[@"version"] isEqual:@1])
        return NO;
    NSArray *raw = state[@"piles"];
    if (![raw isKindOfClass:[NSArray class]] || raw.count != 13)
        return NO;
    NSMutableArray *piles = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id row in raw) {
        if (![row isKindOfClass:[NSArray class]])
            return NO;
        NSMutableArray *pile = [NSMutableArray array];
        for (id item in row) {
            if (![item isKindOfClass:[NSArray class]] || [item count] != 2 ||
                ![item[0] isKindOfClass:[NSNumber class]] || ![item[1] isKindOfClass:[NSNumber class]])
                return NO;
            NSInteger n = [item[0] integerValue];
            if (n < 0 || n >= 52 || [seen containsObject:@(n)])
                return NO;
            [seen addObject:@(n)];
            Card *c = [[Card alloc] initWithIdentifier:n];
            c.faceUp = [item[1] boolValue];
            [pile addObject:c];
        }
        [piles addObject:pile];
    }
    if (seen.count != 52 || ![state[@"moves"] isKindOfClass:[NSNumber class]] ||
        ![state[@"elapsed"] isKindOfClass:[NSNumber class]])
        return NO;
    self.piles = piles;
    self.moves = MAX(0, [state[@"moves"] integerValue]);
    NSTimeInterval elapsed = MAX(0, [state[@"elapsed"] doubleValue]);
    self.started = [NSDate dateWithTimeIntervalSinceNow:-elapsed];
    self.frozenTime = self.won ? elapsed : -1;
    return YES;
}
- (void)pauseTimer {
    if (self.frozenTime < 0)
        self.frozenTime = self.elapsed;
    [self save];
}
- (void)resumeTimer {
    if (!self.won && self.frozenTime >= 0) {
        self.started = [NSDate dateWithTimeIntervalSinceNow:-self.frozenTime];
        self.frozenTime = -1;
    }
}
- (void)save {
    [[NSUserDefaults standardUserDefaults] setObject:[self snapshot] forKey:@"savedGame"];
}
- (void)newGame {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (self.piles && !self.won)
        [d setInteger:0 forKey:@"winStreak"];
    NSMutableArray *piles = [NSMutableArray array];
    for (NSInteger i = 0; i < 13; i++)
        [piles addObject:[NSMutableArray array]];
    self.piles = piles;
    NSMutableArray *deck = [Deck shuffledCards];
    for (NSInteger col = 0; col < 7; col++)
        for (NSInteger row = 0; row <= col; row++) {
            Card *c = deck.lastObject;
            [deck removeLastObject];
            c.faceUp = row == col;
            [self.piles[col + 6] addObject:c];
        }
    [self.piles[0] addObjectsFromArray:deck];
    self.moves = 0;
    self.started = [NSDate date];
    self.frozenTime = -1;
    [self.history removeAllObjects];
    [d setInteger:[d integerForKey:@"gamesPlayed"] + 1 forKey:@"gamesPlayed"];
    [self save];
}
- (BOOL)canLiftFrom:(NSInteger)s index:(NSInteger)i {
    if (self.won || s < 1 || s >= 13 || i < 0 || i >= (NSInteger)self.piles[s].count)
        return NO;
    NSArray *p = self.piles[s];
    Card *c = p[i];
    if (!c.faceUp)
        return NO;
    if (s < 6)
        return i == (NSInteger)p.count - 1;
    for (NSInteger j = i + 1; j < (NSInteger)p.count; j++) {
        Card *a = p[j - 1], *b = p[j];
        if (!b.faceUp || a.red == b.red || a.rank != b.rank + 1)
            return NO;
    }
    return YES;
}
- (BOOL)canMoveFrom:(NSInteger)s index:(NSInteger)i to:(NSInteger)d {
    if (d < 2 || d >= 13 || s == d || ![self canLiftFrom:s index:i])
        return NO;
    Card *c = self.piles[s][i], *top = self.piles[d].lastObject;
    if (d < 6)
        return i == (NSInteger)self.piles[s].count - 1 && c.suit == d - 2 &&
               c.rank == (top ? top.rank + 1 : 1);
    return top ? top.faceUp && top.red != c.red && top.rank == c.rank + 1 : c.rank == 13;
}
- (void)remember {
    [self.history addObject:[self snapshot]];
    if (self.history.count > 200)
        [self.history removeObjectAtIndex:0];
}
- (void)didMove {
    self.moves++;
    if (self.won) {
        self.frozenTime = -[self.started timeIntervalSinceNow];
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setInteger:[d integerForKey:@"wins"] + 1 forKey:@"wins"];
        [d setInteger:[d integerForKey:@"winStreak"] + 1 forKey:@"winStreak"];
    }
    [self save];
}
- (BOOL)moveFrom:(NSInteger)s index:(NSInteger)i to:(NSInteger)d {
    if (![self canMoveFrom:s index:i to:d])
        return NO;
    [self remember];
    NSRange range = NSMakeRange(i, self.piles[s].count - i);
    [self.piles[d] addObjectsFromArray:[self.piles[s] subarrayWithRange:range]];
    [self.piles[s] removeObjectsInRange:range];
    if (s >= 6)
        self.piles[s].lastObject.faceUp = YES;
    [self didMove];
    return YES;
}
- (BOOL)draw {
    if (self.won || (!self.piles[0].count && !self.piles[1].count))
        return NO;
    [self remember];
    if (self.piles[0].count) {
        Card *c = self.piles[0].lastObject;
        [self.piles[0] removeLastObject];
        c.faceUp = YES;
        [self.piles[1] addObject:c];
    } else {
        while (self.piles[1].count) {
            Card *c = self.piles[1].lastObject;
            [self.piles[1] removeLastObject];
            c.faceUp = NO;
            [self.piles[0] addObject:c];
        }
    }
    [self didMove];
    return YES;
}
- (BOOL)undo {
    if (!self.canUndo)
        return NO;
    NSTimeInterval elapsed = self.elapsed;
    NSDictionary *s = self.history.lastObject;
    [self.history removeLastObject];
    [self restore:s];
    self.started = [NSDate dateWithTimeIntervalSinceNow:-elapsed];
    [self save];
    return YES;
}
- (BOOL)autoWinStep {
    if (!self.canAutoWin)
        return NO;
    // With every card face up, the lowest remaining card is always uncovered or in the stock, so playing
    // the lowest available card, and drawing when none is, always finishes.
    NSInteger source = NSNotFound, rank = 14;
    for (NSInteger s = 1; s < 13; s++) {
        Card *top = s == 1 || s >= 6 ? self.piles[s].lastObject : nil;
        if (top && top.rank < rank && [self foundationFor:s index:self.piles[s].count - 1] != NSNotFound) {
            source = s;
            rank = top.rank;
        }
    }
    if (source != NSNotFound)
        return [self moveFrom:source index:self.piles[source].count - 1
                           to:[self foundationFor:source index:self.piles[source].count - 1]];
    return [self draw];
}
- (NSInteger)foundationFor:(NSInteger)s index:(NSInteger)i {
    for (NSInteger d = 2; d < 6; d++)
        if ([self canMoveFrom:s index:i to:d])
            return d;
    return NSNotFound;
}
- (NSInteger)bestDestinationFrom:(NSInteger)s index:(NSInteger)i {
    if (s >= 6 || s == 1) {
        NSInteger foundation = [self foundationFor:s index:i];
        if (foundation != NSNotFound)
            return foundation;
    }
    // Prefer building on a card; an empty pile only helps if it uncovers something.
    NSInteger empty = NSNotFound;
    for (NSInteger d = 6; d < 13; d++)
        if ([self canMoveFrom:s index:i to:d]) {
            if (self.piles[d].count)
                return d;
            if (empty == NSNotFound && !(s >= 6 && i == 0))
                empty = d;
        }
    return empty;
}
@end
