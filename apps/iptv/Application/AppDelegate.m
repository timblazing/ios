#import <UIKit/UIKit.h>
#import "UI/IPTVChannelListController.h"
#import "Configuration/IPTVConfiguration.h"

@interface IPTVAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation IPTVAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    NSString *profile = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.local.iptv.configuration.plist"];
    [IPTVConfiguration applyFile:profile defaults:NSUserDefaults.standardUserDefaults];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[IPTVChannelListController new]];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    nav.navigationBar.translucent = NO;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
