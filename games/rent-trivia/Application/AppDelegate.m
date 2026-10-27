#import <UIKit/UIKit.h>
#import "UI/RTStyle.h"
#import "UI/RTTitleViewController.h"
#import "UI/RTQuizViewController.h"
#import "UI/RTResultsViewController.h"
#import "UI/RTCastViewController.h"
#import "UI/RTMoviePlayer.h"

@interface RTAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation RTAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = UIColor.blackColor;
    self.window.rootViewController = [self initialScreen];
    [self.window makeKeyAndVisible];
    return YES;
}

// RT_SCREEN picks a starting screen for simulator screenshots; the device always starts at the title.
- (UIViewController *)initialScreen {
    NSString *screen = NSProcessInfo.processInfo.environment[@"RT_SCREEN"];
    if ([screen hasPrefix:@"quiz"]) {
        RTQuizViewController *quiz = [[RTQuizViewController alloc] initWithCount:10];
        NSInteger skip = [[screen componentsSeparatedByString:@":"].lastObject integerValue];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
            for (NSInteger i = 0; i < skip; i++) {
                [quiz performSelector:@selector(choose:) withObject:[quiz valueForKey:@"_tiles"][i % 4]];
                [quiz performSelector:@selector(advance)];
            }
            if ([screen hasSuffix:@"!"])
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [quiz performSelector:@selector(choose:) withObject:[quiz valueForKey:@"_tiles"][1]];
                });
        });
        return quiz;
    }
    if ([screen isEqualToString:@"results"]) return [[RTResultsViewController alloc] initWithCorrect:8 of:10 bestStreak:5 results:@[@1, @1, @0, @1, @1, @1, @1, @1, @0, @1]];
    if ([screen isEqualToString:@"cast"]) return [RTCastViewController new];
    if ([screen hasPrefix:@"movie"]) {
        RTTitleViewController *title = [RTTitleViewController new];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [RTMoviePlayer playFrom:title]; });
        return title;
    }
    return [RTTitleViewController new];
}
@end

void RTShowScreen(UIViewController *controller) {
    UIWindow *window = UIApplication.sharedApplication.delegate.window;
    if (RTStyle.reduceMotion) {
        window.rootViewController = controller;
        return;
    }
    [UIView transitionWithView:window duration:0.45 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        BOOL wasEnabled = UIView.areAnimationsEnabled;
                        [UIView setAnimationsEnabled:NO];
                        window.rootViewController = controller;
                        [UIView setAnimationsEnabled:wasEnabled];
                    }
                    completion:nil];
}
