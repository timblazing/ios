#import <Foundation/Foundation.h>
#import "../Application/Guide/IPTVGuideClient.h"

static void Pump(NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([end timeIntervalSinceNow] > 0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}
static BOOL Reload(IPTVGuideClient *client, NSArray *bases) {
    __block BOOL done = NO, success = NO;
    [client reloadBaseURLs:bases completion:^(BOOL ok) { done = YES; success = ok; }];
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:12];
    while (!done && [end timeIntervalSinceNow] > 0) Pump(0.01);
    NSCAssert(done, @"Request must complete within its bounded timeout");
    return success;
}
static void Control(NSString *base, NSString *mode) {
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:[base stringByAppendingFormat:@"/control?%@", mode]]];
    NSCAssert(data, @"Fixture control must respond");
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSCAssert(argc == 2, @"Fixture URL required");
        NSString *root = @(argv[1]);
        NSString *home = [root stringByAppendingString:@"/home"], *bridge = [root stringByAppendingString:@"/bridge"];
        IPTVGuideClient *client = [IPTVGuideClient new];
        Control(root, @"home=up");
        NSCAssert(Reload(client, @[home, bridge]) && [client.baseURL isEqual:home], @"Prefer home");
        IPTVGuide *first = client.guide;
        NSCAssert(Reload(client, @[home, bridge]) && client.guide == first, @"304 preserves cached guide");
        Control(root, @"home=down");
        NSCAssert(Reload(client, @[home, bridge]) && [client.baseURL isEqual:bridge], @"HTTP failure falls back");
        NSCAssert([client.guide.leagues.firstObject.channels.firstObject.stream.host isEqual:@"127.0.0.1"], @"Keep bridge stream addresses");
        Control(root, @"home=up");
        NSCAssert(Reload(client, @[home, bridge]) && [client.baseURL isEqual:home], @"Return home on next refresh");
        NSCAssert(![client.guide.leagues.firstObject.channels.firstObject.stream.host isEqual:@"127.0.0.1"], @"Replace bridge stream addresses with home data");
        for (NSString *path in @[@"/malformed", @"/slow", @"/uncached304"]) {
            IPTVGuideClient *test = [IPTVGuideClient new];
            NSCAssert(Reload(test, @[[root stringByAppendingString:path], bridge]) && [test.baseURL isEqual:bridge], @"Invalid, timed-out or uncached 304 response falls back");
        }
        NSCAssert(Reload(client, @[@"http://127.0.0.1:1", bridge]) && [client.baseURL isEqual:bridge], @"Refused connection falls back");
        NSCAssert(Reload(client, @[@"file:///tmp/no", @"http://user:pass@192.0.2.1", bridge]), @"Invalid configured origins skipped");
        IPTVGuide *last = client.guide; NSString *lastBase = client.baseURL;
        NSCAssert(!Reload(client, @[[root stringByAppendingString:@"/unavailable"]]), @"All routes unavailable");
        NSCAssert(client.guide == last && [client.baseURL isEqual:lastBase], @"Preserve last valid guide and logo origin");
        NSCAssert(!Reload(client, @[]), @"Empty configuration completes safely");
        __block BOOL cancelledCallback = NO;
        [client reloadBaseURLs:@[[root stringByAppendingString:@"/slow"]] completion:^(BOOL ok) { (void)ok; cancelledCallback = YES; }];
        Pump(0.1); [client cancel];
        NSCAssert(Reload(client, @[home, bridge]), @"Reload immediately after cancellation");
        Pump(0.2);
        NSCAssert(!cancelledCallback && [client.baseURL isEqual:home], @"Cancelled response cannot replace new route");
        puts("Gateway HTTP checks passed: preference, failover, recovery, route-specific 304, malformed data, timeout, last-good preservation and cancellation");
    }
    return 0;
}
