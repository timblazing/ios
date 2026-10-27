#import <AVKit/AVKit.h>
#import "../Stream/IPTVPlaylist.h"

@interface IPTVPlayerController : AVPlayerViewController
- (instancetype)initWithChannel:(IPTVChannel *)channel;
@end
