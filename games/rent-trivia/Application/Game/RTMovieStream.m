#import "RTMovieStream.h"

static NSString *const RTDeviceId = @"rent-trivia-ipad";

@implementation RTMovieStream

- (instancetype)initWithServer:(NSString *)server itemId:(NSString *)itemId apiKey:(NSString *)apiKey {
    if ((self = [super init])) {
        _server = [server hasSuffix:@"/"] ? [server substringToIndex:server.length - 1] : [server copy];
        _itemId = [itemId copy];
        _apiKey = [apiKey copy];
        _playSessionId = [[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""].lowercaseString;
    }
    return self;
}

- (NSURL *)playlistURL {
    NSURLComponents *c = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@/Videos/%@/master.m3u8", _server, _itemId]];
    NSDictionary *q = @{
        @"MediaSourceId": _itemId, @"PlaySessionId": _playSessionId, @"DeviceId": RTDeviceId,
        @"VideoCodec": @"h264", @"h264-profile": @"high", @"h264-level": @"41",
        @"MaxWidth": @"1280", @"VideoBitrate": @"2500000",
        @"AudioCodec": @"aac", @"AudioStreamIndex": @"1", @"MaxAudioChannels": @"2", @"AudioBitrate": @"160000",
        @"SubtitleStreamIndex": @"2", @"SubtitleMethod": @"Hls",
        @"SegmentContainer": @"ts", @"BreakOnNonKeyFrames": @"false",
    };
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *k in [q.allKeys sortedArrayUsingSelector:@selector(compare:)]) [items addObject:[NSURLQueryItem queryItemWithName:k value:q[k]]];
    c.queryItems = items;
    return c.URL;
}

- (NSURL *)stopURL {
    NSURLComponents *c = [NSURLComponents componentsWithString:[_server stringByAppendingString:@"/Videos/ActiveEncodings"]];
    c.queryItems = @[[NSURLQueryItem queryItemWithName:@"DeviceId" value:RTDeviceId], [NSURLQueryItem queryItemWithName:@"PlaySessionId" value:_playSessionId]];
    return c.URL;
}

- (NSDictionary<NSString *, NSString *> *)headers {
    NSString *auth = [NSString stringWithFormat:@"MediaBrowser Client=\"Rent Trivia\", Device=\"iPad mini\", DeviceId=\"%@\", Version=\"1.1.1\", Token=\"%@\"", RTDeviceId, _apiKey];
    return @{@"Authorization": auth};
}

+ (BOOL)shouldOfferResumeAt:(double)position duration:(double)duration {
    if (!(position >= 60)) return NO;
    return duration <= 0 || position < duration - 300;
}

+ (NSString *)formatTime:(double)seconds {
    long s = (long)MAX(0, seconds);
    if (s >= 3600) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", s / 3600, s / 60 % 60, s % 60];
    return [NSString stringWithFormat:@"%ld:%02ld", s / 60, s % 60];
}
@end
