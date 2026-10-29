#import "IPTVGuide.h"

static NSString *Text(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *Logo(id value) {
    NSString *text = Text(value);
    NSURLComponents *parts = [NSURLComponents componentsWithString:text];
    // Logos always come through the configured gateway, never an arbitrary remote host.
    return !parts.scheme && !parts.host && !parts.fragment && [parts.path isEqualToString:@"/logo"] ? text : @"";
}

@implementation IPTVTeam
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _abbr = [Text(dict[@"abbr"]) copy];
        _name = [Text(dict[@"name"]) copy];
        _nick = [Text(dict[@"nick"]) copy];
        _color = [Text(dict[@"color"]) copy];
        _logo = [Logo(dict[@"logo"]) copy];
        _record = [Text(dict[@"record"]) copy];
        _score = [Text(dict[@"score"]) copy];
    }
    return self;
}
@end

@implementation IPTVGuideChannel
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    NSURLComponents *url = [NSURLComponents componentsWithString:Text(dict[@"stream"])];
    if (!([url.scheme.lowercaseString isEqualToString:@"http"] || [url.scheme.lowercaseString isEqualToString:@"https"]) ||
        !url.host.length || url.user || url.password || !url.URL || !Text(dict[@"name"]).length) return nil;
    if ((self = [super init])) {
        _identifier = [Text(dict[@"id"]) copy];
        _name = [Text(dict[@"name"]) copy];
        _stream = url.URL;
        _logo = [Logo(dict[@"logo"]) copy];
        NSMutableArray *epg = [NSMutableArray array];
        if ([dict[@"epg"] isKindOfClass:NSArray.class]) {
            for (id entry in dict[@"epg"]) {
                if (![entry isKindOfClass:NSDictionary.class]) continue;
                NSDate *start = [IPTVGuide dateFromString:entry[@"start"]];
                NSDate *end = [IPTVGuide dateFromString:entry[@"end"]];
                if (!start || !end || [end compare:start] != NSOrderedDescending) continue;
                [epg addObject:@{@"title": Text(entry[@"title"]), @"start": entry[@"start"], @"end": entry[@"end"]}];
            }
        }
        _epg = [epg copy];
    }
    return self;
}
@end

static NSArray<IPTVGuideChannel *> *Channels(id value) {
    if (![value isKindOfClass:NSArray.class]) return nil;
    NSMutableArray *result = [NSMutableArray array];
    for (id entry in value) {
        IPTVGuideChannel *channel = [[IPTVGuideChannel alloc] initWithDictionary:entry];
        if (!channel) return nil;
        [result addObject:channel];
    }
    return [result copy];
}

@implementation IPTVGame
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    NSDate *start = [IPTVGuide dateFromString:dict[@"start"]];
    NSArray *channels = Channels(dict[@"channels"]);
    NSString *state = Text(dict[@"state"]);
    if (!Text(dict[@"id"]).length || !start || !channels.count ||
        ![@[@"pre", @"in", @"post"] containsObject:state] ||
        ![dict[@"away"] isKindOfClass:NSDictionary.class] || ![dict[@"home"] isKindOfClass:NSDictionary.class]) return nil;
    if ((self = [super init])) {
        _identifier = [dict[@"id"] copy];
        _start = start;
        _state = [state copy];
        _detail = [Text(dict[@"detail"]) copy];
        _tv = [Text(dict[@"tv"]) copy];
        _away = [[IPTVTeam alloc] initWithDictionary:dict[@"away"]];
        _home = [[IPTVTeam alloc] initWithDictionary:dict[@"home"]];
        _channels = channels;
    }
    return self;
}
@end

@implementation IPTVLeague
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class] || !Text(dict[@"id"]).length ||
        !Text(dict[@"title"]).length || ![dict[@"games"] isKindOfClass:NSArray.class]) return nil;
    NSArray *channels = Channels(dict[@"channels"]);
    if (!channels) return nil;
    NSMutableArray *games = [NSMutableArray array];
    for (id entry in dict[@"games"]) {
        IPTVGame *game = [[IPTVGame alloc] initWithDictionary:entry];
        if (!game) return nil;
        [games addObject:game];
    }
    if ((self = [super init])) {
        _identifier = [dict[@"id"] copy];
        _title = [dict[@"title"] copy];
        _games = [games copy];
        _channels = channels;
    }
    return self;
}
@end

@implementation IPTVGuide
+ (NSDate *)dateFromString:(id)value {
    if (![value isKindOfClass:NSString.class]) return nil;
    // ESPN omits seconds; the gateway includes them. Both forms are UTC ISO 8601.
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.lenient = NO;
    for (NSString *format in @[@"yyyy-MM-dd'T'HH:mm:ssXXXXX", @"yyyy-MM-dd'T'HH:mmXXXXX"]) {
        formatter.dateFormat = format;
        NSDate *date = nil;
        NSRange range = NSMakeRange(0, [value length]);
        if ([formatter getObjectValue:&date forString:value range:&range error:NULL] && range.length == [value length]) return date;
    }
    return nil;
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)error {
    if (error) *error = nil;
    id root = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:error] : nil;
    BOOL valid = [root isKindOfClass:NSDictionary.class] && [root[@"leagues"] isKindOfClass:NSArray.class];
    NSMutableArray *leagues = [NSMutableArray array];
    NSMutableSet *identifiers = [NSMutableSet set];
    if (valid) {
        for (id entry in root[@"leagues"]) {
            IPTVLeague *league = [[IPTVLeague alloc] initWithDictionary:entry];
            if (!league || [identifiers containsObject:league.identifier]) { valid = NO; break; }
            [identifiers addObject:league.identifier];
            [leagues addObject:league];
        }
    }
    if (!valid) {
        if (error && !*error) *error = [NSError errorWithDomain:@"IPTVGuide" code:1 userInfo:@{NSLocalizedDescriptionKey: @"The gateway returned an invalid guide."}];
        return nil;
    }
    if ((self = [super init])) {
        _updated = [IPTVGuide dateFromString:root[@"updated"]];
        _leagues = [leagues copy];
    }
    return self;
}
@end
