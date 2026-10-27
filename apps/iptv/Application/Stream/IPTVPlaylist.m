#import "IPTVPlaylist.h"

@implementation IPTVChannel
@end

@implementation IPTVPlaylist

// Splits `key="value"` attributes from the part of an #EXTINF line before the title comma.
static NSDictionary<NSString *, NSString *> *IPTVAttributes(NSString *info, NSString **title) {
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    BOOL quoted = NO;
    NSUInteger comma = NSNotFound;
    for (NSUInteger i = 0; i < info.length; i++) {
        unichar c = [info characterAtIndex:i];
        if (c == '"') quoted = !quoted;
        else if (c == ',' && !quoted) {
            comma = i;
            break;
        }
    }
    NSString *head = comma == NSNotFound ? info : [info substringToIndex:comma];
    *title = comma == NSNotFound ? @"" : [[info substringFromIndex:comma + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"([A-Za-z0-9_-]+)=\"([^\"]*)\"" options:0 error:NULL];
    for (NSTextCheckingResult *m in [re matchesInString:head options:0 range:NSMakeRange(0, head.length)]) {
        attrs[[head substringWithRange:[m rangeAtIndex:1]].lowercaseString] = [head substringWithRange:[m rangeAtIndex:2]];
    }
    return attrs;
}

static NSURL *IPTVResolve(NSString *string, NSURL *base) {
    NSString *s = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!s.length) return nil;
    return [NSURL URLWithString:s relativeToURL:base].absoluteURL;
}

+ (NSArray<IPTVChannel *> *)channelsFromM3U:(NSString *)text baseURL:(NSURL *)baseURL {
    NSMutableArray *channels = [NSMutableArray array];
    IPTVChannel *pending = nil;
    NSString *normalized = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    for (NSString *raw in [normalized componentsSeparatedByString:@"\n"]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([line hasPrefix:@"﻿"]) line = [line substringFromIndex:1];
        if (!line.length) continue;
        if ([line hasPrefix:@"#EXTINF:"]) {
            NSString *title = nil;
            NSDictionary<NSString *, NSString *> *attrs = IPTVAttributes([line substringFromIndex:8], &title);
            pending = [IPTVChannel new];
            pending.name = title.length ? title : (attrs[@"tvg-name"] ?: @"Channel");
            pending.number = attrs[@"tvg-chno"] ?: @"";
            pending.group = attrs[@"group-title"].length ? attrs[@"group-title"] : @"Channels";
            pending.logoURL = IPTVResolve(attrs[@"tvg-logo"], baseURL);
        } else if ([line hasPrefix:@"#"]) {
            continue;
        } else if (pending) {
            pending.streamURL = IPTVResolve(line, baseURL);
            if (pending.streamURL) [channels addObject:pending];
            pending = nil;
        }
    }
    return channels;
}

+ (NSArray<NSDictionary *> *)groupedChannels:(NSArray<IPTVChannel *> *)channels {
    NSMutableArray<NSDictionary *> *groups = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray *> *byTitle = [NSMutableDictionary dictionary];
    for (IPTVChannel *channel in channels) {
        NSMutableArray *list = byTitle[channel.group];
        if (!list) {
            list = [NSMutableArray array];
            byTitle[channel.group] = list;
            [groups addObject:@{@"title": channel.group, @"channels": list}];
        }
        [list addObject:channel];
    }
    return groups;
}
@end
