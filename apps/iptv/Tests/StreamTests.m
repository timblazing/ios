// macOS harness for the Foundation-only Stream/ code. Modes:
//   stream-tests m3u <fixture.m3u>
//   stream-tests segment <outdir> <file.ts>...   (random chunk sizes, writes every segment to outdir)
//   stream-tests unsupported <file.ts> <codec>  (expects the segmenter to reject the video codec)
//   stream-tests serve <stream-url> <seconds>    (prints "PLAYLIST <url>" once ready, then keeps serving)
#import <Foundation/Foundation.h>
#import "../Application/Stream/IPTVPlaylist.h"
#import "../Application/Stream/IPTVRelay.h"
#import "../Application/Stream/IPTVSegmenter.h"

static int failures = 0;
#define CHECK(cond, ...)                                                                                              \
    do {                                                                                                              \
        if (!(cond)) {                                                                                                \
            failures++;                                                                                               \
            printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__].UTF8String);        \
        }                                                                                                             \
    } while (0)

static int testM3U(NSString *path) {
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSURL *base = [NSURL URLWithString:@"http://192.0.2.10:9191"];
    NSArray<IPTVChannel *> *channels = [IPTVPlaylist channelsFromM3U:text baseURL:base];
    CHECK(channels.count == 4, @"expected 4 channels, got %lu", (unsigned long)channels.count);
    if (channels.count == 4) {
        CHECK([channels[0].name isEqualToString:@"Example One"], @"name %@", channels[0].name);
        CHECK([channels[0].number isEqualToString:@"100"], @"number %@", channels[0].number);
        CHECK([channels[0].group isEqualToString:@"Sports, Live"], @"group with comma %@", channels[0].group);
        CHECK([channels[0].logoURL.absoluteString hasSuffix:@"/logos/1/cache/"], @"logo %@", channels[0].logoURL);
        CHECK([channels[0].streamURL.absoluteString hasSuffix:@"0001"], @"stream %@", channels[0].streamURL);
        CHECK([channels[2].group isEqualToString:@"Channels"], @"default group %@", channels[2].group);
        CHECK([channels[2].streamURL.absoluteString isEqualToString:@"http://192.0.2.10:9191/proxy/ts/stream/00000000-0000-0000-0000-000000000003"],
              @"relative stream %@", channels[2].streamURL);
        CHECK(channels[2].number.length == 0, @"missing number should be empty");
    }
    NSArray *groups = [IPTVPlaylist groupedChannels:channels];
    CHECK(groups.count == 3, @"groups %lu", (unsigned long)groups.count);
    if (groups.count == 3) CHECK([groups[0][@"channels"] count] == 2, @"first group size");
    printf("m3u: %lu channels, %lu groups\n", (unsigned long)channels.count, (unsigned long)groups.count);
    return failures;
}

static int testSegment(NSString *outDir, NSArray<NSString *> *files) {
    [NSFileManager.defaultManager createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:NULL];
    srandom(12345);
    for (NSString *file in files) {
        NSData *input = [NSData dataWithContentsOfFile:file];
        CHECK(input.length > 0, @"cannot read %@", file);
        NSString *name = file.lastPathComponent.stringByDeletingPathExtension;
        IPTVSegmenter *segmenter = [IPTVSegmenter new];
        segmenter.windowSize = 3;
        __block int count = 0;
        __block double total = 0;
        segmenter.onSegment = ^(IPTVSegment *segment) {
            NSString *path = [outDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%03llu.ts", name, segment.sequence]];
            [segment.data writeToFile:path atomically:NO];
            const uint8_t *b = segment.data.bytes;
            CHECK(segment.data.length % 188 == 0, @"segment %llu length %lu", segment.sequence, (unsigned long)segment.data.length);
            CHECK(b[0] == 0x47 && (b[1] & 0x1F) == 0 && b[2] == 0, @"segment %llu does not start with PAT", segment.sequence);
            CHECK(segment.duration >= 1.0 && segment.duration < 20, @"duration %f", segment.duration);
            count++;
            total += segment.duration;
        };
        NSUInteger pos = 0;
        while (pos < input.length) {
            NSUInteger n = MIN(1 + (NSUInteger)(random() % 70000), input.length - pos);
            @autoreleasepool {
                [segmenter feed:[input subdataWithRange:NSMakeRange(pos, n)]];
            }
            pos += n;
        }
        CHECK(count >= 1, @"%@: no segments", name);
        CHECK(segmenter.segmentCount <= 3, @"window not bounded: %lu", (unsigned long)segmenter.segmentCount);
        NSString *playlist = segmenter.playlist;
        CHECK([playlist containsString:@"#EXT-X-MEDIA-SEQUENCE:"] && ![playlist containsString:@"ENDLIST"], @"playlist");
        printf("segment: %s -> %d segments, %.2fs of video\n%s", name.UTF8String, count, total, playlist.UTF8String);
        // A garbage prefix must not break resync.
        IPTVSegmenter *noisy = [IPTVSegmenter new];
        __block int noisyCount = 0;
        noisy.onSegment = ^(IPTVSegment *segment) { noisyCount += segment ? 1 : 0; };
        NSMutableData *dirty = [NSMutableData dataWithLength:0];
        uint8_t junk[333];
        for (int i = 0; i < 333; i++) junk[i] = 0x47 ^ (uint8_t)i;
        [dirty appendBytes:junk length:333];
        [dirty appendData:input];
        [noisy feed:dirty];
        CHECK(noisyCount >= 1, @"%@: resync after junk produced no segments", name);
    }
    return failures;
}

static int serve(NSString *url, NSTimeInterval seconds) {
    IPTVRelay *relay = [[IPTVRelay alloc] initWithStreamURL:[NSURL URLWithString:url]];
    relay.onReady = ^(NSURL *playlist) {
        printf("PLAYLIST %s\n", playlist.absoluteString.UTF8String);
        fflush(stdout);
    };
    relay.onFailure = ^(NSError *error) {
        printf("FAILURE %s\n", error.localizedDescription.UTF8String);
        fflush(stdout);
        exit(2);
    };
    [relay start];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [relay stop];
        printf("STOPPED\n");
        fflush(stdout);
        exit(0);
    });
    dispatch_main();
}

static void testUnsupported(NSString *file, NSString *expected) {
    NSData *input = [NSData dataWithContentsOfFile:file];
    CHECK(input.length > 0, @"cannot read %@", file);
    IPTVSegmenter *segmenter = [IPTVSegmenter new];
    __block int count = 0;
    segmenter.onSegment = ^(IPTVSegment *segment) { count += segment ? 1 : 0; };
    [segmenter feed:input];
    CHECK([segmenter.unsupportedVideo isEqualToString:expected], @"unsupportedVideo %@", segmenter.unsupportedVideo);
    CHECK(count == 0, @"made %d segments from unsupported video", count);
    printf("unsupported: %s -> %s\n", file.lastPathComponent.UTF8String, segmenter.unsupportedVideo.UTF8String);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSString *mode = argc > 1 ? @(argv[1]) : @"";
        if ([mode isEqualToString:@"m3u"] && argc > 2) testM3U(@(argv[2]));
        else if ([mode isEqualToString:@"segment"] && argc > 3) {
            NSMutableArray *files = [NSMutableArray array];
            for (int i = 3; i < argc; i++) [files addObject:@(argv[i])];
            testSegment(@(argv[2]), files);
        } else if ([mode isEqualToString:@"unsupported"] && argc > 3) {
            testUnsupported(@(argv[2]), @(argv[3]));
        } else if ([mode isEqualToString:@"serve"] && argc > 3) {
            return serve(@(argv[2]), atof(argv[3]));
        } else {
            fprintf(stderr, "usage: see header comment\n");
            return 64;
        }
        printf(failures ? "FAILED (%d)\n" : "OK\n", failures);
        return failures ? 1 : 0;
    }
}
