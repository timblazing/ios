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
// Dances a stand-in line of kings and queens without winning; any touch on the board ends it.
@property(nonatomic, readonly) BOOL previewing;
@property(nonatomic, copy) void (^previewEnded)(void);
- (void)previewCelebration;
- (void)endPreview;
@end
