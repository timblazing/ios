#import "../Game/WordleGame.h"
#import <UIKit/UIKit.h>

// One letter square. LetterStateNone is an unrevealed tile: outlined, darker once it has a letter.
@interface TileView : UIView
@property(nonatomic, copy) NSString *letter;
@property(nonatomic) LetterState state;
- (void)applyTheme;
- (void)pop;
// Flips closed, takes the new colors, and flips back open.
- (void)flipToState:(LetterState)state delay:(NSTimeInterval)delay completion:(void (^)(void))completion;
- (void)bounceAfter:(NSTimeInterval)delay;
- (void)shake;
- (void)cancelAnimations;
@end
