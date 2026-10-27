#import "TileView.h"
#import <UIKit/UIKit.h>

// Six rows of five tiles.
@interface BoardView : UIView
@property(nonatomic) CGFloat tileSize, gap;
- (TileView *)tileAtRow:(NSUInteger)row column:(NSUInteger)column;
- (CGSize)boardSize;
- (void)reset;
- (void)setLetters:(NSString *)letters inRow:(NSUInteger)row;
- (void)setStates:(NSArray<NSNumber *> *)states inRow:(NSUInteger)row;
- (void)revealRow:(NSUInteger)row
           states:(NSArray<NSNumber *> *)states
         animated:(BOOL)animated
       completion:(void (^)(void))completion;
- (void)bounceRow:(NSUInteger)row;
- (void)shakeRow:(NSUInteger)row;
- (void)applyTheme;
@end
