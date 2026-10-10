#import <UIKit/UIKit.h>

// Streams the film from Jellyfin in the system player, with resume and a key prompt when the server refuses.
@interface RTMoviePlayer : NSObject
+ (void)playFrom:(UIViewController *)presenter;
+ (void)editKeyFrom:(UIViewController *)presenter;
@end
