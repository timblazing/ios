#import "../Game/SolitaireGame.h"
#import <SpriteKit/SpriteKit.h>
@interface GameScene : SKScene
@property(nonatomic, strong) SolitaireGame *game;
@property(nonatomic, copy) void (^gameChanged)(void);
// Height covered by the controls bar; the background runs under it, the cards stay above it.
@property(nonatomic) CGFloat bottomInset;
- (void)preloadTextures;
- (void)refreshAnimated:(BOOL)animated;
- (void)cancelInteraction;
- (void)celebrate;
@end
