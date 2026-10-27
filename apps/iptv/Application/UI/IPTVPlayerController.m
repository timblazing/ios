#import "IPTVPlayerController.h"
#import <AVFoundation/AVFoundation.h>
#import "../Stream/IPTVRelay.h"

// AVPlayerViewController observes KVO itself on iOS 10, so ours needs its own context.
static void *IPTVStatusContext = &IPTVStatusContext;
// Start this far behind the newest segment: enough for the next segment to arrive before playback reaches the end.
static const double IPTVLiveEdgeBehind = 5.0;

@implementation IPTVPlayerController {
    IPTVChannel *_channel;
    IPTVRelay *_relay;
    UIActivityIndicatorView *_spinner;
    UIButton *_close;
    AVPlayerItem *_item;
    BOOL _started, _failed, _tornDown;
}

- (instancetype)initWithChannel:(IPTVChannel *)channel {
    if ((self = [super init])) {
        _channel = channel;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [_spinner startAnimating];
    [self.contentOverlayView addSubview:_spinner];
    _close = [UIButton buttonWithType:UIButtonTypeSystem];
    [_close setTitle:@"Close" forState:UIControlStateNormal];
    _close.accessibilityLabel = @"Close player";
    [_close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentOverlayView addSubview:_close];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(closeTapped) name:UIApplicationDidEnterBackgroundNotification object:nil];

    __weak typeof(self) weakSelf = self;
    _relay = [[IPTVRelay alloc] initWithStreamURL:_channel.streamURL];
    _relay.onReady = ^(NSURL *playlist) { [weakSelf play:playlist]; };
    _relay.onFailure = ^(NSError *error) { [weakSelf failWith:error]; };
    [_relay start];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.contentOverlayView.bounds;
    _spinner.center = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
    _close.frame = CGRectMake(16, 24, 80, 44);
}

- (void)play:(NSURL *)playlist {
    _item = [AVPlayerItem playerItemWithURL:playlist];
    [_item addObserver:self forKeyPath:@"status" options:0 context:IPTVStatusContext];
    self.player = [AVPlayer playerWithPlayerItem:_item];
    self.player.automaticallyWaitsToMinimizeStalling = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != IPTVStatusContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_tornDown) return;
        AVPlayerItem *item = self->_item;
        if (item.status == AVPlayerItemStatusReadyToPlay && !self->_started) {
            self->_started = YES;
            NSValue *range = item.seekableTimeRanges.lastObject;
            void (^go)(void) = ^{
                [self->_spinner stopAnimating];
                self->_close.hidden = YES;
                [self.player play];
            };
            if (range) {
                CMTimeRange r = range.CMTimeRangeValue;
                double want = MAX(CMTimeGetSeconds(r.start), CMTimeGetSeconds(CMTimeRangeGetEnd(r)) - IPTVLiveEdgeBehind);
                if (want > CMTimeGetSeconds(item.currentTime) + 1) {
                    CMTime tol = CMTimeMakeWithSeconds(1, 600);
                    [self.player seekToTime:CMTimeMakeWithSeconds(want, 600) toleranceBefore:tol toleranceAfter:tol completionHandler:^(BOOL f) { go(); }];
                    return;
                }
            }
            go();
        } else if (item.status == AVPlayerItemStatusFailed) {
            [self failWith:item.error];
        }
    });
}

- (void)failWith:(NSError *)error {
    if (_failed || _tornDown) return;
    _failed = YES;
    [self tearDown];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Can't play %@", _channel.name]
                                                                    message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeTapped {
    [self tearDown];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed) [self tearDown];
}

- (void)tearDown {
    if (_tornDown) return;
    _tornDown = YES;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self.player pause];
    if (_item) [_item removeObserver:self forKeyPath:@"status" context:IPTVStatusContext];
    _item = nil;
    self.player = nil;
    _relay.onReady = nil;
    _relay.onFailure = nil;
    [_relay stop];
    _relay = nil;
}
@end
