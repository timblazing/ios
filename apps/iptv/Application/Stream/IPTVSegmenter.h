#import <Foundation/Foundation.h>

@interface IPTVSegment : NSObject
@property(nonatomic, readonly) uint64_t sequence;
@property(nonatomic, readonly) NSData *data;
@property(nonatomic, readonly) double duration;
@property(nonatomic, readonly) BOOL discontinuity;
@end

// Repackages a live MPEG-TS byte stream into self-contained HLS segments without transcoding.
// feed: and markDiscontinuity must be called from one serial context; everything else is thread-safe.
@interface IPTVSegmenter : NSObject
@property(nonatomic) double targetDuration; // minimum segment length in seconds, default 2.0
@property(nonatomic) NSUInteger windowSize; // segments kept in memory, default 8
// Called on the feeding thread after each segment is finished.
@property(nonatomic, copy) void (^onSegment)(IPTVSegment *segment);
@property(nonatomic, readonly) NSUInteger segmentCount;
@property(nonatomic, readonly) uint64_t producedCount;
// Set once the PMT names a video codec the A7 can't decode (anything but H.264), e.g. @"HEVC (H.265)".
@property(nonatomic, readonly, copy) NSString *unsupportedVideo;

- (void)feed:(NSData *)data;
// Call when the source reconnects: drops the partial segment and marks the next one as a discontinuity.
- (void)markDiscontinuity;
// Live media playlist for the current window, or nil before the first segment.
- (NSString *)playlist;
- (IPTVSegment *)segmentWithSequence:(uint64_t)sequence;
@end
