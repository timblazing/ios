#import "IPTVRelay.h"
#import "IPTVLocalServer.h"

NSString *const IPTVRelayErrorDomain = @"IPTVRelay";

static const NSUInteger IPTVReadySegments = 3;
// Dispatcharr sends ~30s of buffered video as a fast burst on connect. Publishing the playlist mid-burst would let the
// window slide past the player, so wait for segments to arrive at roughly real-time pace (or give up waiting).
static const NSTimeInterval IPTVBurstSettleLimit = 12;
static const NSTimeInterval IPTVStartTimeout = 30;

@interface IPTVRelay () <NSURLSessionDataDelegate>
@end

@implementation IPTVRelay {
    NSURL *_streamURL;
    dispatch_queue_t _queue; // serial: owns all state below and is the URL session's delegate queue
    NSURLSession *_session;
    NSURLSessionDataTask *_task;
    IPTVLocalServer *_server;
    BOOL _stopped, _ready, _retried;
    BOOL _ownerStopped; // main thread only: the owner called -stop, so no more callbacks
    NSTimeInterval _firstSegmentTime, _lastSegmentTime;
}

- (instancetype)initWithStreamURL:(NSURL *)streamURL {
    if ((self = [super init])) {
        _streamURL = streamURL;
        _segmenter = [IPTVSegmenter new];
        _queue = dispatch_queue_create("com.local.iptv.relay", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)start {
    dispatch_async(_queue, ^{
        if (self->_stopped || self->_session) return;
        self->_server = [[IPTVLocalServer alloc] initWithSegmenter:self->_segmenter];
        NSError *error = nil;
        if (![self->_server start:&error]) {
            [self failWithError:error];
            return;
        }
        __weak typeof(self) weakSelf = self;
        self->_segmenter.onSegment = ^(IPTVSegment *segment) { [weakSelf segmentFinished:segment]; };
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 15; // idle time between chunks, so a stalled source is noticed
        config.timeoutIntervalForResource = 0;
        NSOperationQueue *delegateQueue = [NSOperationQueue new];
        delegateQueue.maxConcurrentOperationCount = 1;
        delegateQueue.underlyingQueue = self->_queue;
        self->_session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:delegateQueue];
        [self connect];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(IPTVStartTimeout * NSEC_PER_SEC)), self->_queue, ^{
            if (!self->_ready && !self->_stopped) {
                [self failWithError:[NSError errorWithDomain:IPTVRelayErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"The channel did not start in time."}]];
            }
        });
    });
}

- (void)connect {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_streamURL];
    request.timeoutInterval = 15;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    _task = [_session dataTaskWithRequest:request];
    [_task resume];
}

- (void)stop {
    _ownerStopped = YES;
    [self halt];
}

- (void)halt {
    dispatch_async(_queue, ^{
        self->_stopped = YES;
        self->_segmenter.onSegment = nil;
        [self->_task cancel];
        [self->_session invalidateAndCancel]; // also releases the session's strong reference to this delegate
        self->_session = nil;
        [self->_server stop];
        self->_server = nil;
    });
}

- (NSURL *)playlistURL {
    __block NSURL *url = nil;
    dispatch_sync(_queue, ^{
        if (self->_ready) url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/live.m3u8", self->_server.port]];
    });
    return url;
}

#pragma mark - State (runs on _queue)

- (void)segmentFinished:(IPTVSegment *)segment {
    if (_ready || _stopped) return;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (!_firstSegmentTime) _firstSegmentTime = now;
    NSTimeInterval gap = _lastSegmentTime ? now - _lastSegmentTime : 0;
    _lastSegmentTime = now;
    if (_segmenter.segmentCount < IPTVReadySegments) return;
    BOOL realtime = gap >= 0.5 * segment.duration;
    if (!realtime && now - _firstSegmentTime < IPTVBurstSettleLimit) return;
    _ready = YES;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/live.m3u8", _server.port]];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_ownerStopped && self.onReady) self.onReady(url);
    });
}

- (void)failWithError:(NSError *)error {
    if (_stopped) return;
    _stopped = YES; // the halt below runs later on this queue; ignore further data and errors until then
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_ownerStopped) return;
        void (^handler)(NSError *) = self.onFailure;
        if (handler) handler(error);
    });
    [self halt];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
    completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 200;
    if (status != 200) {
        completionHandler(NSURLSessionResponseCancel);
        NSString *message = [NSString stringWithFormat:@"The server answered HTTP %ld.", (long)status];
        [self failWithError:[NSError errorWithDomain:IPTVRelayErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}]];
        return;
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (_stopped || dataTask != _task) return;
    [_segmenter feed:data];
    NSString *codec = _segmenter.unsupportedVideo;
    if (codec) {
        NSString *message = [NSString stringWithFormat:@"This channel uses %@ video, which this iPad can't decode. Only H.264 channels play.", codec];
        [self failWithError:[NSError errorWithDomain:IPTVRelayErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: message}]];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (_stopped || task != _task) return;
    if (error.code == NSURLErrorCancelled) return;
    if (!_retried) {
        _retried = YES;
        [_segmenter markDiscontinuity]; // the new connection starts with another burst of already-seen video
        [self connect];
        return;
    }
    NSError *failure = error ?: [NSError errorWithDomain:IPTVRelayErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"The stream ended."}];
    [self failWithError:failure];
}
@end
