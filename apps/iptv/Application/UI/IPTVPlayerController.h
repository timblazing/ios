#import <UIKit/UIKit.h>
#import "../Guide/IPTVGuide.h"

@interface IPTVPlayerController : UIViewController
- (instancetype)initWithGames:(NSArray<IPTVGame *> *)games index:(NSUInteger)index;
- (instancetype)initWithChannel:(IPTVGuideChannel *)channel;
@end
