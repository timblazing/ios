#import <UIKit/UIKit.h>
@interface GameControls : UIView
@property(nonatomic, strong, readonly) UIButton *undoButton;
@property(nonatomic, strong, readonly) UIButton *restartButton;
@property(nonatomic, strong, readonly) UIButton *settingsButton;
// Hidden until every tableau card is face up.
@property(nonatomic, strong, readonly) UIButton *autoWinButton;
@property(nonatomic, strong, readonly) UILabel *status;
@end
