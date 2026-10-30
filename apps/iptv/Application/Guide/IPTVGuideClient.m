#import "IPTVGuideClient.h"

@implementation IPTVGuideClient {
    NSURLSession *_session;
    NSURLSessionDataTask *_task;
    NSString *_etag;
    BOOL _loading;
    NSUInteger _generation;
}
- (instancetype)init {
    if ((self = [super init])) {
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 4;
        config.timeoutIntervalForResource = 6;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}
- (void)reloadBaseURLs:(NSArray<NSString *> *)bases completion:(void (^)(BOOL))completion {
    if (_loading) return;
    NSMutableArray *valid = [NSMutableArray new];
    for (id raw in bases) {
        if (![raw isKindOfClass:NSString.class]) continue;
        NSString *base = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        while ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length-1];
        NSURLComponents *url = [NSURLComponents componentsWithString:base];
        if (![@[@"http", @"https"] containsObject:url.scheme.lowercaseString] || !url.host.length ||
            !url.URL || url.user || url.password || url.query || url.fragment || [valid containsObject:base]) continue;
        [valid addObject:base];
    }
    _loading = YES;
    [self tryBases:valid index:0 generation:_generation completion:completion];
}
- (void)tryBases:(NSArray<NSString *> *)bases index:(NSUInteger)index generation:(NSUInteger)generation completion:(void (^)(BOOL))completion {
    if (index == bases.count) { _loading = NO; completion(NO); return; }
    NSString *base = bases[index];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/guide.json"]]
                                                        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:4];
    // A validator belongs to the endpoint that supplied the cached guide.
    BOOL conditional = _guide && _etag.length && [base isEqual:_baseURL];
    if (conditional) [request setValue:_etag forHTTPHeaderField:@"If-None-Match"];
    __weak typeof(self) weakSelf = self;
    _task = [_session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
        IPTVGuide *guide = !error && http.statusCode == 200 && data ? [[IPTVGuide alloc] initWithData:data error:NULL] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || generation != self->_generation) return;
            self->_task = nil;
            if (guide || (!error && http.statusCode == 304 && conditional)) {
                if (guide) {
                    self->_guide = guide;
                    self->_baseURL = [base copy];
                    self->_etag = [http.allHeaderFields objectForKey:@"Etag"] ?: [http.allHeaderFields objectForKey:@"ETag"];
                }
                self->_loading = NO;
                completion(YES);
            } else [self tryBases:bases index:index+1 generation:generation completion:completion];
        });
    }];
    [_task resume];
}
- (void)cancel {
    _generation++;
    [_task cancel]; _task = nil;
    _loading = NO;
}
- (void)dealloc { [_session invalidateAndCancel]; }
@end
