#import "IPTVConfiguration.h"

@implementation IPTVConfiguration
+ (BOOL)applyFile:(NSString *)path defaults:(NSUserDefaults *)defaults {
    NSDictionary *profile = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!profile) return NO;
    NSMutableDictionary *values = [NSMutableDictionary new];
    for (NSString *key in @[@"gateway.baseURL", @"gateway.fallbackBaseURL", @"server.baseURL"]) {
        id raw = profile[key];
        if (!raw) continue;
        if (![raw isKindOfClass:NSString.class]) return NO;
        NSString *value = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([key isEqual:@"gateway.fallbackBaseURL"] && !value.length) { values[key] = @""; continue; }
        NSURLComponents *url = [NSURLComponents componentsWithString:value];
        if (![@[@"http", @"https"] containsObject:url.scheme.lowercaseString] || !url.host.length ||
            url.user || url.password || url.query || url.fragment) return NO;
        while ([value hasSuffix:@"/"]) value = [value substringToIndex:value.length-1];
        values[key] = value;
    }
    if (!values.count) return NO;
    for (NSString *key in values) {
        if ([values[key] length]) [defaults setObject:values[key] forKey:key];
        else [defaults removeObjectForKey:key];
    }
    return YES;
}
@end
