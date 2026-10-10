#import "../Application/Game/Deck.h"
#import "../Application/Game/SolitaireGame.h"
#import <Foundation/Foundation.h>
#include <stdlib.h>

@interface SolitaireGame (Testing)
- (NSDictionary *)snapshot;
- (BOOL)restore:(NSDictionary *)state;
@end
static NSUInteger assertions = 0;
#define CHECK(...)                                                                                           \
    do {                                                                                                     \
        assertions++;                                                                                        \
        if (!(__VA_ARGS__)) {                                                                                \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #__VA_ARGS__);                           \
            exit(1);                                                                                         \
        }                                                                                                    \
    } while (0)

static SolitaireGame *Fixture(NSDictionary<NSNumber *, NSArray *> *rows) {
    NSMutableArray *piles = [NSMutableArray array];
    NSMutableSet *used = [NSMutableSet set];
    for (NSInteger p = 0; p < 13; p++) {
        NSArray *row = rows[@(p)] ?: @[];
        [piles addObject:[row mutableCopy]];
        for (NSArray *card in row)
            [used addObject:card[0]];
    }
    for (NSInteger i = 0; i < 52; i++)
        if (![used containsObject:@(i)])
            [piles[0] addObject:@[ @(i), @NO ]];
    SolitaireGame *game = [SolitaireGame new];
    CHECK([game restore:@{@"piles" : piles, @"version" : @1, @"moves" : @0, @"elapsed" : @0}]);
    return game;
}
static void Conserved(SolitaireGame *game) {
    NSMutableSet *ids = [NSMutableSet set];
    NSUInteger count = 0;
    for (NSArray *pile in game.piles)
        for (Card *card in pile) {
            [ids addObject:@(card.identifier)];
            count++;
        }
    CHECK(count == 52);
    CHECK(ids.count == 52);
    for (Card *c in game.piles[0])
        CHECK(!c.faceUp);
    for (Card *c in game.piles[1])
        CHECK(c.faceUp);
    for (NSInteger p = 2; p < 6; p++) {
        NSInteger rank = 1;
        for (Card *c in game.piles[p]) {
            CHECK(c.faceUp);
            CHECK(c.rank == rank++);
            CHECK(c.suit == p - 2);
        }
    }
    for (NSInteger p = 6; p < 13; p++) {
        BOOL faceUp = NO;
        Card *previous = nil;
        for (Card *c in game.piles[p]) {
            if (faceUp) {
                CHECK(c.faceUp);
                CHECK(previous.rank == c.rank + 1);
                CHECK(previous.red != c.red);
            }
            faceUp = c.faceUp;
            previous = c;
        }
        if (previous)
            CHECK(previous.faceUp);
    }
}
static void TestDealAndStock(void) {
    SolitaireGame *g = [SolitaireGame new];
    [g newGame];
    Conserved(g);
    CHECK(g.piles[0].count == 24);
    CHECK(g.piles[1].count == 0);
    CHECK(g.moves == 0);
    CHECK(!g.canUndo);
    for (NSInteger p = 6; p < 13; p++) {
        CHECK(g.piles[p].count == (NSUInteger)(p - 5));
        for (NSInteger i = 0; i < p - 5; i++)
            CHECK(g.piles[p][i].faceUp == (i == p - 6));
    }
    NSArray *original = [g snapshot][@"piles"];
    NSInteger first = g.piles[0].lastObject.identifier;
    CHECK([g draw]);
    CHECK(g.piles[1].lastObject.identifier == first);
    CHECK(g.moves == 1);
    CHECK(g.canUndo);
    CHECK([g undo]);
    CHECK([[g snapshot][@"piles"] isEqual:original]);
    CHECK(g.moves == 0);
    for (int i = 0; i < 24; i++)
        CHECK([g draw]);
    CHECK(g.piles[0].count == 0);
    CHECK(g.piles[1].count == 24);
    CHECK([g draw]);
    CHECK([[g snapshot][@"piles"] isEqual:original]);
    CHECK(g.moves == 25);
    CHECK([g undo]);
    CHECK(g.piles[0].count == 0);
    CHECK(g.piles[1].count == 24);
    CHECK(g.moves == 24);
    CHECK([g draw]);
    CHECK([g draw]);
    CHECK(g.piles[1].lastObject.identifier == first);
    [g save];
    SolitaireGame *loaded = [SolitaireGame new];
    CHECK([[loaded snapshot][@"piles"] isEqual:[g snapshot][@"piles"]]);
    CHECK(loaded.moves == g.moves);
}
static void TestTableau(void) {
    // Hidden 3 clubs, red Q hearts, black J clubs move together onto black K spades.
    SolitaireGame *g = Fixture(
        @{@6 : @[ @[ @28, @NO ], @[ @11, @YES ], @[ @36, @YES ] ],
          @7 : @[ @[ @51, @YES ] ]});
    CHECK(![g canLiftFrom:6 index:0]);
    CHECK([g canLiftFrom:6 index:1]);
    CHECK([g canMoveFrom:6 index:1 to:7]);
    CHECK(![g canMoveFrom:6 index:1 to:8]);
    CHECK(![g canMoveFrom:6 index:1 to:6]);
    CHECK(![g canMoveFrom:6 index:1 to:0]);
    CHECK(![g canMoveFrom:-1 index:0 to:7]);
    CHECK(![g canMoveFrom:6 index:99 to:7]);
    NSArray *before = [g snapshot][@"piles"];
    CHECK([g moveFrom:6 index:1 to:7]);
    CHECK(g.piles[6].lastObject.faceUp);
    CHECK(g.piles[7].count == 3);
    Conserved(g);
    CHECK([g undo]);
    CHECK([[g snapshot][@"piles"] isEqual:before]);
    CHECK(!g.piles[6][0].faceUp);
    g = Fixture(@{@6 : @[ @[ @12, @YES ], @[ @24, @YES ] ]});
    CHECK(![g canLiftFrom:6 index:0]); // same color
    g = Fixture(@{@6 : @[ @[ @12, @YES ], @[ @35, @YES ] ]});
    CHECK(![g canLiftFrom:6 index:0]); // rank gap
    g = Fixture(@{@6 : @[ @[ @12, @YES ], @[ @37, @NO ] ]});
    CHECK(![g canLiftFrom:6 index:0]); // hidden tail
    g = Fixture(@{@6 : @[ @[ @12, @YES ], @[ @37, @YES ] ]});
    CHECK([g canMoveFrom:6 index:0 to:7]); // king sequence
    CHECK([g moveFrom:6 index:0 to:7]);
    Conserved(g);
}
static void TestFoundations(void) {
    SolitaireGame *g = Fixture(
        @{@1 : @[ @[ @13, @YES ], @[ @0, @YES ] ],
          @6 : @[ @[ @1, @YES ] ],
          @7 : @[ @[ @27, @YES ] ]});
    CHECK(![g canLiftFrom:1 index:0]);
    CHECK([g foundationFor:1 index:1] == 2);
    CHECK(![g canMoveFrom:1 index:1 to:3]);
    CHECK(![g canMoveFrom:6 index:0 to:2]);
    CHECK([g moveFrom:1 index:1 to:2]);
    CHECK([g moveFrom:6 index:0 to:2]);
    CHECK(![g canMoveFrom:2 index:0 to:6]);
    CHECK(![g canMoveFrom:7 index:0 to:2]);
    CHECK([g undo]);
    CHECK([g canMoveFrom:2 index:0 to:7]);
    CHECK([g moveFrom:2 index:0 to:7]);
    Conserved(g);
    g = Fixture(@{@6 : @[ @[ @0, @YES ], @[ @38, @YES ] ]});
    CHECK(![g canMoveFrom:6 index:0 to:2]);
}
static void TestBestDestination(void) {
    // Hearts 0–12, diamonds 13–25, clubs 26–38, spades 39–51; rank = id % 13 + 1.
    SolitaireGame *g = Fixture(
        @{@1 : @[ @[ @0, @YES ] ],
          @2 : @[],
          @6 : @[ @[ @51, @YES ] ],
          @7 : @[ @[ @49, @NO ], @[ @11, @YES ], @[ @36, @YES ] ],
          @8 : @[ @[ @25, @YES ] ]});
    CHECK([g bestDestinationFrom:1 index:0] == 2);           // ace to its foundation
    CHECK([g bestDestinationFrom:6 index:0] == NSNotFound);  // lone king stays put
    CHECK([g bestDestinationFrom:7 index:1] == 6);           // Q♥ J♣ run onto K♠
    CHECK([g bestDestinationFrom:7 index:2] == NSNotFound);  // J♣ has nowhere to go
    CHECK([g bestDestinationFrom:7 index:0] == NSNotFound);  // face-down card
    CHECK([g moveFrom:7 index:1 to:6]);
    CHECK([g bestDestinationFrom:8 index:0] == NSNotFound);  // nor does a lone king on the other side
    CHECK([g bestDestinationFrom:7 index:0] == NSNotFound);  // flipped J♠: J♣ now covers Q♥
    Conserved(g);
    g = Fixture(@{@1 : @[ @[ @12, @YES ] ], @6 : @[ @[ @0, @NO ], @[ @38, @YES ] ], @7 : @[ @[ @1, @YES ] ]});
    CHECK([g bestDestinationFrom:1 index:0] == 8);  // waste king to the first empty pile
    CHECK([g bestDestinationFrom:6 index:1] == 8);  // K♣ off a face-down card
    CHECK([g bestDestinationFrom:7 index:0] == NSNotFound);
}
static void TestWinAndStats(void) {
    NSMutableDictionary *rows = [NSMutableDictionary dictionary];
    for (NSInteger suit = 0; suit < 4; suit++) {
        NSMutableArray *row = [NSMutableArray array];
        for (NSInteger rank = 0; rank < (suit == 3 ? 12 : 13); rank++)
            [row addObject:@[ @(suit * 13 + rank), @YES ]];
        rows[@(suit + 2)] = row;
    }
    rows[@6] = @[ @[ @51, @YES ] ];
    SolitaireGame *g = Fixture(rows);
    CHECK(!g.won);
    CHECK(![g draw]);
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSInteger wins = [d integerForKey:@"wins"], streak = [d integerForKey:@"winStreak"];
    CHECK([g moveFrom:6 index:0 to:5]);
    CHECK(g.won);
    CHECK(!g.canUndo);
    CHECK(![g undo]);
    CHECK(![g draw]);
    CHECK(![g moveFrom:5 index:12 to:6]);
    CHECK([d integerForKey:@"wins"] == wins + 1);
    CHECK([d integerForKey:@"winStreak"] == streak + 1);
    SolitaireGame *loaded = [SolitaireGame new];
    CHECK(loaded.won);
    CHECK([d integerForKey:@"wins"] == wins + 1);
    NSInteger played = [d integerForKey:@"gamesPlayed"];
    [loaded newGame];
    CHECK([d integerForKey:@"gamesPlayed"] == played + 1);
    CHECK([d integerForKey:@"winStreak"] == streak + 1);
    [loaded newGame];
    CHECK([d integerForKey:@"winStreak"] == 0);
    CHECK(![loaded restore:@{}]);
    CHECK(![loaded restore:@{@"version" : @1, @"piles" : @[]}]);
    NSMutableDictionary *bad = [[loaded snapshot] mutableCopy];
    NSMutableArray *piles = [bad[@"piles"] mutableCopy];
    NSMutableArray *stock = [piles[0] mutableCopy];
    stock[0] = stock[1];
    piles[0] = stock;
    bad[@"piles"] = piles;
    CHECK(![loaded restore:bad]);
}
static void TestAutoWin(void) {
    // K♠ Q♥ in one column, K♥ alone in another, a face-up 5♣ on the waste, the rest face down in the stock.
    SolitaireGame *g = Fixture(@{
        @1 : @[ @[ @30, @YES ] ],
        @6 : @[ @[ @51, @YES ], @[ @11, @YES ] ],
        @7 : @[ @[ @12, @YES ] ]
    });
    CHECK(g.canAutoWin);
    NSInteger steps = 0;
    while ([g autoWinStep])
        CHECK(++steps < 5000);
    CHECK(g.won);
    CHECK(!g.canAutoWin);
    CHECK(![g autoWinStep]);
    Conserved(g);
    SolitaireGame *hidden = Fixture(@{@6 : @[ @[ @51, @NO ], @[ @11, @YES ] ]});
    CHECK(!hidden.canAutoWin);
    CHECK(![hidden autoWinStep]);
    for (NSInteger round = 0; round < 50; round++) {
        SolitaireGame *r = [SolitaireGame new];
        [r newGame];
        for (NSInteger p = 6; p < 13; p++)
            while (r.piles[p].count > 1) {
                [r.piles[1] addObject:r.piles[p].firstObject];
                [r.piles[p] removeObjectAtIndex:0];
            }
        for (Card *c in r.piles[1])
            c.faceUp = YES;
        CHECK(r.canAutoWin);
        steps = 0;
        while ([r autoWinStep])
            CHECK(++steps < 5000);
        CHECK(r.won);
        Conserved(r);
    }
}
static void TestTimer(void) {
    SolitaireGame *g = [SolitaireGame new];
    [g newGame];
    [g pauseTimer];
    NSTimeInterval paused = g.elapsed;
    [NSThread sleepForTimeInterval:0.02];
    CHECK(g.elapsed == paused);
    [g resumeTimer];
    [NSThread sleepForTimeInterval:0.02];
    CHECK(g.elapsed > paused);
    [g pauseTimer];
    SolitaireGame *loaded = [SolitaireGame new];
    CHECK(loaded.elapsed >= g.elapsed);
}
static void TestRandomPlay(void) {
    // Explore legal moves and undo across fresh deals, checking full board invariants.
    for (int deal = 0; deal < 20; deal++) {
        SolitaireGame *g = [SolitaireGame new];
        [g newGame];
        for (int step = 0; step < 120; step++) {
            @autoreleasepool {
                Conserved(g);
                NSMutableArray *choices = [NSMutableArray array];
                for (NSInteger s = 1; s < 13; s++)
                    for (NSInteger i = 0; i < (NSInteger)g.piles[s].count; i++)
                        for (NSInteger d = 2; d < 13; d++)
                            if ([g canMoveFrom:s index:i to:d])
                                [choices addObject:@[ @(s), @(i), @(d) ]];
                if (g.canUndo && arc4random_uniform(8) == 0)
                    CHECK([g undo]);
                else if (choices.count && arc4random_uniform(4) != 0) {
                    NSArray *m = choices[arc4random_uniform((uint32_t)choices.count)];
                    CHECK([g moveFrom:[m[0] integerValue] index:[m[1] integerValue] to:[m[2] integerValue]]);
                } else
                    [g draw];
            }
        }
        Conserved(g);
    }
}
int main(void) {
    @autoreleasepool {
        // The executable has its own defaults domain; never run tests under the app's bundle identifier.
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        for (NSString *key in @[ @"savedGame", @"gamesPlayed", @"wins", @"winStreak" ])
            [d removeObjectForKey:key];
        TestDealAndStock();
        TestTableau();
        TestFoundations();
        TestBestDestination();
        TestWinAndStats();
        TestAutoWin();
        TestTimer();
        TestRandomPlay();
        printf("PASS: %lu assertions; deal, stock/recycle, moves, flips, undo, persistence, stats, victory, auto-win, "
               "2400 random steps.\n",
               (unsigned long)assertions);
    }
    return 0;
}
