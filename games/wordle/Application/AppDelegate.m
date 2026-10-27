#import "AppDelegate.h"
#import "GameViewController.h"
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [GameViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
