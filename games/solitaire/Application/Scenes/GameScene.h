#import "../Game/SolitaireGame.h"
#import <SpriteKit/SpriteKit.h>
@interface GameScene : SKScene
@property(nonatomic, strong) SolitaireGame *game;
@property(nonatomic, copy) void (^gameChanged)(void);
// Height covered by the controls bar; the background runs under it, the cards stay above it.
@property(nonatomic) CGFloat bottomInset;
@property(nonatomic, readonly) BOOL autoPlaying;
- (void)preloadTextures;
- (void)refreshAnimated:(BOOL)animated;
- (void)cancelInteraction;
// Plays the game out to the foundations one card at a time. Any interaction cancel stops it.
- (void)autoWin;
// Lines up the kings and queens to dance until the next game.
- (void)celebrate;
@end
