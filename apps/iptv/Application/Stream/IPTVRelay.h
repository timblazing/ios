#import <Foundation/Foundation.h>
#import "IPTVSegmenter.h"

extern NSString *const IPTVRelayErrorDomain;

// Pulls a channel's MPEG-TS over HTTP, repackages it as HLS in memory, and serves it on 127.0.0.1.
@interface IPTVRelay : NSObject
@property(nonatomic, readonly) NSURL *playlistURL; // nil until the relay is ready
@property(nonatomic, readonly) IPTVSegmenter *segmenter;
// Both are delivered on the main queue, and not at all after -stop. Call -start and -stop on the main thread.
@property(nonatomic, copy) void (^onReady)(NSURL *playlistURL);
@property(nonatomic, copy) void (^onFailure)(NSError *error);

- (instancetype)initWithStreamURL:(NSURL *)streamURL;
- (void)start;
- (void)stop;
@end
