#import <UIKit/UIKit.h>
#import "PaintViewController.h"

@interface PaintAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation PaintAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [PaintViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
