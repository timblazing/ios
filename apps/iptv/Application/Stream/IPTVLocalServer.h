#import <Foundation/Foundation.h>
#import "IPTVSegmenter.h"

// Minimal HTTP/1.1 server on 127.0.0.1 that serves a segmenter's live playlist and segments to AVPlayer.
@interface IPTVLocalServer : NSObject
@property(nonatomic, readonly) uint16_t port;
- (instancetype)initWithSegmenter:(IPTVSegmenter *)segmenter;
- (BOOL)start:(NSError **)error;
- (void)stop; // closes the listening socket; call to break the server's reference to itself
@end
