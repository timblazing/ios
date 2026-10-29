#import <Foundation/Foundation.h>
#import "../Application/Guide/IPTVGuide.h"

static int failures;
#define CHECK(value) do { if (!(value)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #value); failures++; } } while (0)

static NSData *JSON(id value) {
    return [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingFragmentsAllowed error:NULL];
}

static void Reject(id root) {
    NSError *error = nil;
    CHECK([[IPTVGuide alloc] initWithData:JSON(root) error:&error] == nil);
    CHECK(error != nil);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 64;
        NSData *data = [NSData dataWithContentsOfFile:@(argv[1])];
        NSError *error = nil;
        IPTVGuide *guide = [[IPTVGuide alloc] initWithData:data error:&error];
        CHECK(guide != nil && error == nil);
        CHECK(guide.leagues.count == 3);
        CHECK(guide.updated != nil);
        CHECK([guide.leagues[0].identifier isEqualToString:@"nfl"]);
        CHECK([guide.leagues[1].title isEqualToString:@"NBA"]);
        CHECK([guide.leagues[2].identifier isEqualToString:@"ncaaf"]);
        CHECK(guide.leagues[0].games.count == 14);
        CHECK(guide.leagues[1].games.count == 3);
        CHECK(guide.leagues[2].channels.count == 18);
        NSUInteger feedCount = 0;
        for (IPTVLeague *league in guide.leagues) {
            for (IPTVGame *game in league.games) {
                CHECK(game.start != nil && game.away.abbr.length && game.home.abbr.length);
                CHECK([game.state isEqualToString:@"pre"] || [game.state isEqualToString:@"in"] || [game.state isEqualToString:@"post"]);
                CHECK(game.channels.count > 0);
                if ([game.state isEqualToString:@"pre"]) CHECK(game.away.score.length == 0 && game.home.score.length == 0);
                feedCount += game.channels.count;
                for (IPTVGuideChannel *channel in game.channels) {
                    CHECK([channel.stream.host isEqualToString:@"192.0.2.10"]);
                    CHECK([channel.stream.query isEqualToString:@"output_format=hls"]);
                }
            }
        }
        CHECK(feedCount > 22); // Duplicate feeds remain available for failover.
        CHECK([[IPTVGuide dateFromString:@"2026-10-30T00:15Z"] isEqualToDate:[IPTVGuide dateFromString:@"2026-10-30T00:15:00Z"]]);
        CHECK([[IPTVGuide dateFromString:@"2026-10-29T19:15:00-05:00"] isEqualToDate:[IPTVGuide dateFromString:@"2026-10-30T00:15Z"]]);
        CHECK([IPTVGuide dateFromString:NSNull.null] == nil);
        CHECK([IPTVGuide dateFromString:@"2026-10-30T00:15Zjunk"] == nil);
        CHECK([IPTVGuide dateFromString:@"garbage"] == nil);
        Reject(@[]);
        Reject(@{});
        Reject(@{@"leagues": NSNull.null});
        Reject(@{@"leagues": @[@"bad"]});
        CHECK([[IPTVGuide alloc] initWithData:[@"{" dataUsingEncoding:NSUTF8StringEncoding] error:&error] == nil);
        CHECK([[IPTVGuide alloc] initWithData:[NSData data] error:&error] == nil && error != nil);
        IPTVGuide *empty = [[IPTVGuide alloc] initWithData:JSON(@{@"leagues": @[]}) error:&error];
        CHECK(empty != nil && empty.leagues.count == 0 && error == nil);

        NSDictionary *original = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
        NSMutableDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
        NSMutableDictionary *league = root[@"leagues"][0];
        NSMutableDictionary *game = league[@"games"][0];
        NSMutableDictionary *channel = game[@"channels"][0];
        NSString *stream = channel[@"stream"];
        for (NSString *unsafe in @[@"file:///tmp/video", @"javascript:alert(1)", @"/relative", @"http:///missing", @"http://user:password@example.com/live"]) {
            channel[@"stream"] = unsafe;
            Reject(root);
        }
        channel[@"stream"] = stream;
        game[@"state"] = @"unknown";
        Reject(root);
        game[@"state"] = @"pre";
        game[@"start"] = NSNull.null;
        Reject(root);
        game[@"start"] = @"2026-10-30T00:15Z";
        game[@"away"] = @[];
        Reject(root);
        game[@"away"] = [original[@"leagues"][0][@"games"][0][@"away"] mutableCopy];
        game[@"away"][@"score"] = NSNull.null;
        game[@"away"][@"logo"] = @"//example.com/logo";
        game[@"away"][@"name"] = @42;
        channel[@"logo"] = @"https://example.com/logo";
        channel[@"epg"] = @[@42, @{@"start": NSNull.null}, @{@"title": @42, @"start": @"2026-10-30T00:00Z", @"end": @"2026-10-30T01:00Z"}, @{@"start": @"2026-10-30T01:00Z", @"end": @"2026-10-30T00:00Z"}];
        IPTVGuide *sanitized = [[IPTVGuide alloc] initWithData:JSON(root) error:&error];
        CHECK(sanitized != nil && error == nil);
        IPTVGame *clean = sanitized.leagues[0].games[0];
        CHECK(clean.away.score.length == 0 && clean.away.name.length == 0 && clean.away.logo.length == 0);
        CHECK(clean.channels[0].logo.length == 0);
        CHECK(clean.channels[0].epg.count == 1);
        CHECK([clean.channels[0].epg[0][@"title"] isEqualToString:@""]);
        [root[@"leagues"] addObject:league];
        Reject(root);
        printf("guide: fixture, dates, feed ordering, optional metadata and malformed response checks %s\n", failures ? "FAILED" : "OK");
        return failures ? 1 : 0;
    }
}
