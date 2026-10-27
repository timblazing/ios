#import <UIKit/UIKit.h>

extern NSString *const KeyEnter;
extern NSString *const KeyDelete;

// The on-screen QWERTY keyboard. Keys report single uppercase letters, KeyEnter, or KeyDelete.
@interface KeyboardView : UIView
@property(nonatomic, copy) void (^onKey)(NSString *key);
+ (CGFloat)heightForKeyHeight:(CGFloat)keyHeight;
- (void)setStates:(NSDictionary<NSString *, NSNumber *> *)states animated:(BOOL)animated;
- (void)applyTheme;
@end
