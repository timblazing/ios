#import "WordSource.h"
#import "../Game/PuzzleCalendar.h"
#import "../Game/WordleGame.h"

static NSString *const CacheKey = @"solutions";

@implementation WordSource {
    NSMutableDictionary<NSString *, NSString *> *_cache; // puzzle number → answer
    NSMutableDictionary<NSNumber *, NSMutableArray *> *_waiting;
    NSURLSession *_session;
}
+ (instancetype)shared {
    static WordSource *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [WordSource new];
    });
    return shared;
}
- (instancetype)init {
    if (!(self = [super init]))
        return nil;
    _cache = [NSMutableDictionary dictionary];
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:CacheKey];
    [saved enumerateKeysAndObjectsUsingBlock:^(id key, id word, BOOL *stop) {
        if ([key isKindOfClass:[NSString class]] && [word isKindOfClass:[NSString class]] &&
            [WordleGame isWellFormed:word])
            self->_cache[key] = word;
    }];
    _waiting = [NSMutableDictionary dictionary];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 12;
    config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    _session = [NSURLSession sessionWithConfiguration:config];
    return self;
}
- (NSString *)cachedSolutionForDay:(NSInteger)day {
    return _cache[@(day).stringValue];
}
- (BOOL)isKnownAnswer:(NSString *)word {
    return [_cache.allValues containsObject:word];
}
- (void)solutionForDay:(NSInteger)day completion:(void (^)(NSString *))completion {
    NSString *cached = [self cachedSolutionForDay:day];
    if (cached || day < 0) {
        if (completion)
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(cached);
            });
        return;
    }
    NSMutableArray *waiting = _waiting[@(day)];
    BOOL inFlight = waiting != nil;
    if (!waiting)
        waiting = _waiting[@(day)] = [NSMutableArray array];
    if (completion)
        [waiting addObject:[completion copy]];
    if (inFlight)
        return;
    NSString *url =
        [NSString stringWithFormat:@"https://www.nytimes.com/svc/wordle/v2/%@.json", [PuzzleCalendar keyForDay:day]];
    [[_session dataTaskWithURL:[NSURL URLWithString:url]
             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                 NSString *word = nil;
                 if (data && [(NSHTTPURLResponse *)response statusCode] == 200) {
                     id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                     id solution = [json isKindOfClass:[NSDictionary class]] ? json[@"solution"] : nil;
                     if ([solution isKindOfClass:[NSString class]] &&
                         [WordleGame isWellFormed:[solution uppercaseString]])
                         word = [solution uppercaseString];
                 }
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [self finishDay:day word:word];
                 });
             }] resume];
}
- (void)finishDay:(NSInteger)day word:(NSString *)word {
    if (word) {
        _cache[@(day).stringValue] = word;
        [[NSUserDefaults standardUserDefaults] setObject:_cache forKey:CacheKey];
    }
    NSArray *waiting = _waiting[@(day)];
    [_waiting removeObjectForKey:@(day)];
    for (void (^completion)(NSString *) in waiting)
        completion(word);
}
- (void)prefetchFromDay:(NSInteger)day count:(NSInteger)count {
    for (NSInteger d = day; d < day + count; d++)
        if (![self cachedSolutionForDay:d])
            [self solutionForDay:d completion:nil];
}
- (void)randomDayBefore:(NSInteger)today
              excluding:(NSInteger)excluded
             completion:(void (^)(NSInteger, NSString *))completion {
    if (today < 2) {
        completion(-1, nil);
        return;
    }
    NSInteger day;
    do
        day = arc4random_uniform((uint32_t)today);
    while (day == excluded);
    [self solutionForDay:day
              completion:^(NSString *word) {
                  if (word) {
                      completion(day, word);
                      return;
                  }
                  NSMutableArray<NSNumber *> *past = [NSMutableArray array];
                  for (NSString *key in self->_cache) {
                      NSInteger d = key.integerValue;
                      if (d < today && d != excluded)
                          [past addObject:@(d)];
                  }
                  if (!past.count) {
                      completion(-1, nil);
                      return;
                  }
                  NSInteger pick = past[arc4random_uniform((uint32_t)past.count)].integerValue;
                  completion(pick, [self cachedSolutionForDay:pick]);
              }];
}
@end
