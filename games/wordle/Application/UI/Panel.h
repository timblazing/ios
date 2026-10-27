#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PanelStyle) {
    PanelStylePage,   // covers the game, like Wordle's help and settings
    PanelStyleModal,  // a centered card over a faded game, like statistics
    PanelStyleDrawer, // slides in from the left, like the menu
};

// Base overlay with a title and close button. Subclasses add rows with addRow:spacing: (stacked top to
// bottom, labels sized to fit) or override layoutContentForWidth: for custom layout.
@interface Panel : UIView
@property(nonatomic, readonly) PanelStyle style;
@property(nonatomic, readonly) UIView *contentView;
@property(nonatomic, copy) void (^onClose)(void);
- (instancetype)initWithStyle:(PanelStyle)style title:(NSString *)title;
- (void)addRow:(UIView *)view spacing:(CGFloat)spacing;
- (CGFloat)layoutContentForWidth:(CGFloat)width;
- (void)applyTheme;
- (void)showInView:(UIView *)view;
- (void)dismiss;
// Helpers for subclasses.
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font;
- (UIView *)divider;
@end
