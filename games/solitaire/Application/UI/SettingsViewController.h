#import <UIKit/UIKit.h>
@interface SettingsViewController : UITableViewController
@property(nonatomic, copy) void (^onClose)(void);
// Called after Settings closes, to show the win celebration without winning.
@property(nonatomic, copy) void (^onPreviewCelebration)(void);
@end
