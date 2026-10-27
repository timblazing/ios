#import <Foundation/Foundation.h>

// Builds the Jellyfin HLS request for the movie. Jellyfin transcodes the HEVC/EAC3 source to
// 720p H.264 High 4.1 + stereo AAC, which the A7 can decode.
@interface RTMovieStream : NSObject
@property(nonatomic, copy, readonly) NSString *server;
@property(nonatomic, copy, readonly) NSString *itemId;
@property(nonatomic, copy, readonly) NSString *apiKey;
@property(nonatomic, copy, readonly) NSString *playSessionId;

- (instancetype)initWithServer:(NSString *)server itemId:(NSString *)itemId apiKey:(NSString *)apiKey;
- (NSURL *)playlistURL;
- (NSURL *)stopURL;  // DELETE this to end the server-side transcode
// Jellyfin 12 only accepts the token in this header, so it has to go on every playlist and segment request.
- (NSDictionary<NSString *, NSString *> *)headers;

// Offers a resume point only when it's meaningfully into the film and not at the credits.
+ (BOOL)shouldOfferResumeAt:(double)position duration:(double)duration;
+ (NSString *)formatTime:(double)seconds;  // 1:02:14 or 4:05
@end
