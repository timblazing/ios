#import "Card.h"
// Piles: 0 stock, 1 waste, 2–5 foundations (hearts, diamonds, clubs, spades), 6–12 tableau.
@interface SolitaireGame : NSObject
@property(nonatomic, readonly) NSArray<NSMutableArray<Card *> *> *piles;
@property(nonatomic, readonly) NSInteger moves;
@property(nonatomic, readonly) BOOL won;
@property(nonatomic, readonly) BOOL canUndo;
// Every tableau card is face up, so the rest plays out to the foundations without a choice.
@property(nonatomic, readonly) BOOL canAutoWin;
@property(nonatomic, readonly) NSTimeInterval elapsed;
- (void)newGame;
- (BOOL)canLiftFrom:(NSInteger)source index:(NSInteger)index;
- (BOOL)canMoveFrom:(NSInteger)source index:(NSInteger)index to:(NSInteger)destination;
- (BOOL)moveFrom:(NSInteger)source index:(NSInteger)index to:(NSInteger)destination;
- (BOOL)draw;
- (BOOL)undo;
// One auto-win move: the lowest playable card to its foundation, else a draw. NO once nothing is left.
- (BOOL)autoWinStep;
- (NSInteger)foundationFor:(NSInteger)source index:(NSInteger)index;
// Where a tap sends the card at index: its foundation, else a tableau pile, or NSNotFound.
- (NSInteger)bestDestinationFrom:(NSInteger)source index:(NSInteger)index;
- (void)save;
- (void)pauseTimer;
- (void)resumeTimer;
@end
