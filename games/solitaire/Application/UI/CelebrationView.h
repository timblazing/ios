#import <UIKit/UIKit.h>
// The win screen over everything: confetti across the whole screen, the WordArt message, clip-art stars,
// and the time and moves. Touches pass through, so the controls bar still works.
@interface CelebrationView : UIView
// Height of the controls bar; the stats sit just above it.
@property(nonatomic) CGFloat bottomInset;
@property(nonatomic, readonly) BOOL showing;
- (void)showWithTime:(NSString *)time moves:(NSInteger)moves hint:(NSString *)hint;
- (void)hide;
@end
