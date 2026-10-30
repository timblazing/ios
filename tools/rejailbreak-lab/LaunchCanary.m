#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <sys/sysctl.h>

// No exploit, network request, process launch, or write outside this app's container.
@interface LaunchCanary : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UITextView *text;
@property(nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@end

@implementation LaunchCanary
- (void)record:(NSString *)event {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self record:event]; });
        return;
    }
    struct timeval boot = {0};
    size_t size = sizeof(boot);
    sysctlbyname("kern.boottime", &boot, &size, NULL, 0);
    UIApplication *app = [UIApplication sharedApplication];
    NSString *line = [NSString stringWithFormat:@"%@ | %@ | boot=%lld | state=%ld | unlocked=%d\n",
                     [NSDate date], event, (long long)boot.tv_sec, (long)app.applicationState,
                     app.protectedDataAvailable];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"launches.txt"];
    // Container access before first unlock still needs testing, even with ProtectionNone.
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data]
            attributes:@{NSFileProtectionKey : NSFileProtectionNone}];
    }
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    [file seekToEndOfFile];
    [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [file closeFile];
    NSString *log = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    self.text.text = [@"Launch Canary\n\nHarmless startup logger. No jailbreak code.\n\n" stringByAppendingString:log ?: @""];
}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.backgroundTask = UIBackgroundTaskInvalid;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *controller = [UIViewController new];
    self.text = [[UITextView alloc] initWithFrame:self.window.bounds];
    self.text.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.text.editable = NO;
    self.text.font = [UIFont systemFontOfSize:18];
    self.text.textContainerInset = UIEdgeInsetsMake(32, 20, 20, 20);
    controller.view = self.text;
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    [self record:[NSString stringWithFormat:@"didFinishLaunching optionKeys=%@", options.allKeys ?: @[]]];
    // The deprecated API is the subject of this experiment, retained for iOS 10.
    SEL keepAlive = NSSelectorFromString(@"setKeepAliveTimeout:handler:");
    BOOL registered = NO;
    if ([app respondsToSelector:keepAlive]) {
        typedef BOOL (*RegisterKeepAlive)(id, SEL, NSTimeInterval, void (^)(void));
        registered = ((RegisterKeepAlive)objc_msgSend)(app, keepAlive, 600,
            ^{ [self record:@"legacyKeepAlive"]; });
    }
    [self record:[NSString stringWithFormat:@"keepAliveRegistered=%d", registered]];
    self.backgroundTask = [app beginBackgroundTaskWithExpirationHandler:^{
        [self record:@"backgroundTimeExpired"];
        if (self.backgroundTask != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
    }];
    // Release promptly: this logger does not need a ten-minute background assertion.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self record:@"launchPlusTwoSeconds"];
        if (self.backgroundTask != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
    });
    return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)app { (void)app; [self record:@"didBecomeActive"]; }
- (void)applicationDidEnterBackground:(UIApplication *)app { (void)app; [self record:@"didEnterBackground"]; }
- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)app { (void)app; [self record:@"protectedDataAvailable"]; }
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([LaunchCanary class])); }
}
