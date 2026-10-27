#import <Foundation/Foundation.h>

@interface IPTVChannel : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *number; // tvg-chno, may be empty
@property(nonatomic, copy) NSString *group;
@property(nonatomic, strong) NSURL *logoURL;
@property(nonatomic, strong) NSURL *streamURL;
@end

@interface IPTVPlaylist : NSObject
// Parses an M3U with #EXTINF entries. Relative logo/stream URLs resolve against baseURL (may be nil).
+ (NSArray<IPTVChannel *> *)channelsFromM3U:(NSString *)text baseURL:(NSURL *)baseURL;
// Channels grouped by group-title in order of first appearance: [{@"title": NSString, @"channels": NSArray}].
+ (NSArray<NSDictionary *> *)groupedChannels:(NSArray<IPTVChannel *> *)channels;
@end
