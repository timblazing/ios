#import "IPTVPlayerController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

static void *IPTVStatusContext = &IPTVStatusContext;

@interface IPTVPlayerButton : UIButton
@property(nonatomic) BOOL back;
@property(nonatomic) BOOL paused;
@end
@implementation IPTVPlayerButton
- (void)drawRect:(CGRect)rect {
    [UIColor.whiteColor setStroke];
    UIBezierPath *p = [UIBezierPath bezierPath];
    p.lineWidth = 2.4;
    p.lineCapStyle = kCGLineCapRound;
    if (self.back) {
        [p moveToPoint:CGPointMake(27, 12)];
        [p addLineToPoint:CGPointMake(17, 22)];
        [p addLineToPoint:CGPointMake(27, 32)];
        [p stroke];
    } else {
        [UIColor.whiteColor setFill];
        if (self.paused) {
            [p moveToPoint:CGPointMake(17, 12)];
            [p addLineToPoint:CGPointMake(32, 24)];
            [p addLineToPoint:CGPointMake(17, 36)];
            [p closePath];
            [p fill];
        } else {
            UIRectFill(CGRectMake(16, 13, 5, 23));
            UIRectFill(CGRectMake(27, 13, 5, 23));
        }
    }
}
@end

@interface IPTVPlayerController () <UIGestureRecognizerDelegate>
@end
@implementation IPTVPlayerController {
    NSArray<IPTVGame *> *_games;
    NSUInteger _gameIndex, _feedIndex;
    IPTVGuideChannel *_channel;
    AVPlayer *_player;
    AVPlayerItem *_item;
    AVPlayerLayer *_video;
    UIView *_chrome, *_top, *_bottom;
    CAGradientLayer *_topShade, *_bottomShade;
    IPTVPlayerButton *_back, *_pause;
    UIButton *_live;
    UILabel *_titleLabel, *_networkLabel, *_message, *_toast;
    MPVolumeView *_volume;
    UIActivityIndicatorView *_spinner;
    NSTimer *_timer;
    NSDate *_hideAt, *_toastUntil, *_lastProgress;
    double _lastTime;
    BOOL _paused, _background, _closed, _exhausted;
#if TARGET_OS_SIMULATOR
    BOOL _reportedPlayback;
#endif
}

- (instancetype)initWithGames:(NSArray<IPTVGame *> *)games index:(NSUInteger)index {
    if ((self = [super init])) {
        _games = [games copy];
        _gameIndex = games.count ? MIN(index, games.count - 1) : 0;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}
- (instancetype)initWithChannel:(IPTVGuideChannel *)channel {
    if ((self = [self initWithGames:@[] index:0])) _channel = channel;
    return self;
}
- (IPTVGame *)game { return _games.count ? _games[_gameIndex] : nil; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:NULL];
    _video = [AVPlayerLayer layer];
    _video.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:_video];
    _chrome = [UIView new];
    [self.view addSubview:_chrome];
    _top = [UIView new];
    _bottom = [UIView new];
    [_chrome addSubview:_top];
    [_chrome addSubview:_bottom];
    _topShade = [CAGradientLayer layer];
    _topShade.colors = @[(id)[UIColor colorWithWhite:0 alpha:0.7].CGColor, (id)UIColor.clearColor.CGColor];
    [_top.layer addSublayer:_topShade];
    _bottomShade = [CAGradientLayer layer];
    _bottomShade.colors = @[(id)UIColor.clearColor.CGColor, (id)[UIColor colorWithWhite:0 alpha:0.75].CGColor];
    [_bottom.layer addSublayer:_bottomShade];
    _back = [IPTVPlayerButton buttonWithType:UIButtonTypeCustom];
    _back.back = YES;
    _back.accessibilityLabel = @"Back to guide";
    [_back addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_top addSubview:_back];
    _titleLabel = [self labelWithSize:17];
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _networkLabel = [self labelWithSize:13];
    _networkLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    [_top addSubview:_titleLabel];
    [_top addSubview:_networkLabel];
    _live = [UIButton buttonWithType:UIButtonTypeCustom];
    _live.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _live.layer.cornerRadius = 15;
    [_live setTitle:@"● LIVE" forState:UIControlStateNormal];
    _live.accessibilityLabel = @"Live, jump to live edge";
    _live.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    [_live addTarget:self action:@selector(goLive) forControlEvents:UIControlEventTouchUpInside];
    [_top addSubview:_live];
    _pause = [IPTVPlayerButton buttonWithType:UIButtonTypeCustom];
    _pause.accessibilityLabel = @"Pause";
    [_pause addTarget:self action:@selector(togglePause) forControlEvents:UIControlEventTouchUpInside];
    [_bottom addSubview:_pause];
    _volume = [MPVolumeView new];
    _volume.showsRouteButton = YES;
    _volume.showsVolumeSlider = YES;
    _volume.tintColor = UIColor.whiteColor;
    _volume.accessibilityLabel = @"Volume and AirPlay";
    [_bottom addSubview:_volume];
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.view addSubview:_spinner];
    _message = [self labelWithSize:18];
    _message.numberOfLines = 0;
    [self.view addSubview:_message];
    _toast = [self labelWithSize:18];
    _toast.numberOfLines = 2;
    _toast.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
    _toast.layer.cornerRadius = 14;
    _toast.clipsToBounds = YES;
    _toast.hidden = YES;
    [self.view addSubview:_toast];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControls)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    for (NSNumber *direction in @[@(UISwipeGestureRecognizerDirectionLeft), @(UISwipeGestureRecognizerDirectionRight)]) {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipe:)];
        swipe.direction = direction.unsignedIntegerValue;
        [self.view addGestureRecognizer:swipe];
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(backgrounded) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foregrounded) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self selectGame];
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { [weakSelf tick]; }];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}
- (UILabel *)labelWithSize:(CGFloat)size {
    UILabel *label = [UILabel new];
    label.font = [UIFont systemFontOfSize:size];
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    CGFloat w = b.size.width, h = b.size.height;
    _video.frame = b;
    _chrome.frame = b;
    _top.frame = CGRectMake(0, 0, w, 110);
    _bottom.frame = CGRectMake(0, h - 120, w, 120);
    _topShade.frame = _top.bounds;
    _bottomShade.frame = _bottom.bounds;
    _back.frame = CGRectMake(12, 24, 44, 44);
    _titleLabel.frame = CGRectMake(112, 26, w - 224, 22);
    _networkLabel.frame = CGRectMake(112, 50, w - 224, 18);
    _live.frame = CGRectMake(w - 108, 24, 96, 44);
    _pause.frame = CGRectMake(16, 58, 48, 48);
    _volume.frame = CGRectMake(w - 266, 65, 250, 44);
    _spinner.center = CGPointMake(w / 2, h / 2);
    _message.frame = CGRectMake(80, h / 2 - 65, w - 160, 130);
    _toast.frame = CGRectMake(MAX(20, (w - 440) / 2), h / 2 - 44, MIN(440, w - 40), 88);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for (UIView *v = touch.view; v; v = v.superview) if ([v isKindOfClass:UIControl.class] || [v isKindOfClass:MPVolumeView.class]) return NO;
    return YES;
}
- (void)setControlsVisible:(BOOL)visible {
    _chrome.userInteractionEnabled = visible;
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.2 animations:^{ self->_chrome.alpha = visible ? 1 : 0; }];
    _hideAt = visible ? [NSDate dateWithTimeIntervalSinceNow:3] : nil;
}
- (void)toggleControls { [self setControlsVisible:_chrome.alpha < 0.5]; }
- (void)selectGame {
    [self stopItem];
    _feedIndex = 0;
    _exhausted = NO;
    _paused = NO;
    IPTVGame *game = self.game;
    if (game) {
        _channel = game.channels.firstObject;
        _titleLabel.text = [NSString stringWithFormat:@"%@ at %@", game.away.nick.length ? game.away.nick : game.away.name, game.home.nick.length ? game.home.nick : game.home.name];
        _networkLabel.text = game.tv.length ? game.tv : _channel.name;
    } else {
        _titleLabel.text = _channel.name;
        NSDate *now = NSDate.date;
        for (NSDictionary *entry in _channel.epg) {
            NSDate *start = [IPTVGuide dateFromString:entry[@"start"]], *end = [IPTVGuide dateFromString:entry[@"end"]];
            if ([start compare:now] != NSOrderedDescending && [end compare:now] == NSOrderedDescending && [entry[@"title"] length]) _titleLabel.text = entry[@"title"];
        }
        _networkLabel.text = _channel.name;
    }
    [self setControlsVisible:YES];
    if ([game.state isEqualToString:@"pre"]) {
        NSDateFormatter *date = [NSDateFormatter new];
        date.dateStyle = NSDateFormatterMediumStyle;
        date.timeStyle = NSDateFormatterShortStyle;
        _message.text = [NSString stringWithFormat:@"Starts %@", game.start ? [date stringFromDate:game.start] : game.detail];
        _live.hidden = YES;
        _pause.hidden = YES;
        return;
    }
    _live.hidden = NO;
    _pause.hidden = NO;
    [self startFeed];
}
- (void)startFeed {
    [self stopItem];
    if (_closed || _background) return;
    _message.text = nil;
    _exhausted = NO;
    if (!_channel.stream) { [self feedFailed]; return; }
    [_spinner startAnimating];
    _lastProgress = NSDate.date;
    _lastTime = 0;
#if TARGET_OS_SIMULATOR
    _reportedPlayback = NO;
#endif
    // Construct a fresh asset from the original endpoint, never the expiring redirect token.
    _item = [AVPlayerItem playerItemWithURL:_channel.stream];
    [_item addObserver:self forKeyPath:@"status" options:0 context:IPTVStatusContext];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(itemFailed:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:_item];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(itemEnded:) name:AVPlayerItemDidPlayToEndTimeNotification object:_item];
    _player = [AVPlayer playerWithPlayerItem:_item];
    _player.automaticallyWaitsToMinimizeStalling = YES;
    _video.player = _player;
    if (!_paused) [_player play];
    [self updatePause];
}
- (void)stopItem {
    [_player pause];
    _video.player = nil;
    if (_item) {
        [NSNotificationCenter.defaultCenter removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:_item];
        [NSNotificationCenter.defaultCenter removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_item];
        [_item removeObserver:self forKeyPath:@"status" context:IPTVStatusContext];
        [_item.asset cancelLoading];
    }
    [_player replaceCurrentItemWithPlayerItem:nil];
    _item = nil;
    _player = nil;
    [_spinner stopAnimating];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != IPTVStatusContext) { [super observeValueForKeyPath:keyPath ofObject:object change:change context:context]; return; }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (!self || object != self->_item || self->_closed || self->_background) return;
        if (self->_item.status == AVPlayerItemStatusFailed) [self feedFailed];
    });
}
- (void)itemFailed:(NSNotification *)notification { if (notification.object == _item) [self feedFailed]; }
- (void)itemEnded:(NSNotification *)notification { if (notification.object == _item) [self feedFailed]; }
- (void)feedFailed {
    [self stopItem];
    if (_closed || _background) return;
    IPTVGame *game = self.game;
    if (game && ++_feedIndex < game.channels.count) {
        _channel = game.channels[_feedIndex];
        [self showToast:@"Trying backup feed…"];
        [self startFeed];
    } else {
        _exhausted = YES;
        _message.text = @"This feed is unavailable. Swipe to another game or return to the guide.";
        [self setControlsVisible:YES];
    }
}
- (void)tick {
    if (_closed || _background) return;
    NSDate *now = NSDate.date;
    if (_toastUntil && [now compare:_toastUntil] != NSOrderedAscending) { _toast.hidden = YES; _toastUntil = nil; }
    if (_hideAt && [now compare:_hideAt] != NSOrderedAscending && _item && !_paused && !_exhausted && !UIAccessibilityIsVoiceOverRunning()) [self setControlsVisible:NO];
    if (!_item) return;
    double current = CMTimeGetSeconds(_item.currentTime);
    if (isfinite(current) && current > 0.05 && current > _lastTime + 0.05) {
        #if TARGET_OS_SIMULATOR
        if (!_reportedPlayback && current > 3) {
            _reportedPlayback = YES;
            NSLog(@"TV playback advancing: time=%.1f video=%.0fx%.0f layerReady=%d", current, _item.presentationSize.width, _item.presentationSize.height, _video.readyForDisplay);
        }
#endif
        _lastTime = current;
        _lastProgress = now;
        [_spinner stopAnimating];
    }
    if (!_paused && [now timeIntervalSinceDate:_lastProgress] > 20) { [self feedFailed]; return; }
    BOOL behind = _paused;
    NSValue *range = _item.seekableTimeRanges.lastObject;
    if (range && isfinite(current)) {
        double edge = CMTimeGetSeconds(CMTimeRangeGetEnd(range.CMTimeRangeValue));
        behind |= isfinite(edge) && edge - current > 12;
    }
    NSMutableAttributedString *liveText = [[NSMutableAttributedString alloc] initWithString:behind ? @"GO LIVE" : @"● LIVE"
                                                                                 attributes:@{NSForegroundColorAttributeName: behind ? [UIColor colorWithWhite:0.65 alpha:1] : UIColor.whiteColor}];
    if (!behind) [liveText addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1] range:NSMakeRange(0, 1)];
    [_live setAttributedTitle:liveText forState:UIControlStateNormal];
    _live.backgroundColor = [UIColor colorWithWhite:1 alpha:behind ? 0.08 : 0.12];
    _live.accessibilityLabel = behind ? @"Go live" : @"Live, jump to live edge";
}
- (void)goLive {
    if (!_item || _exhausted) return;
    NSValue *range = _item.seekableTimeRanges.lastObject;
    _paused = NO;
    _lastProgress = NSDate.date;
    if (range) {
        CMTimeRange r = range.CMTimeRangeValue;
        double edge = CMTimeGetSeconds(CMTimeRangeGetEnd(r));
        double start = CMTimeGetSeconds(r.start);
        if (isfinite(edge) && isfinite(start)) [_player seekToTime:CMTimeMakeWithSeconds(MAX(start, edge - 3), 600)];
    }
    [_player play];
    [self updatePause];
    [self setControlsVisible:YES];
}
- (void)updatePause {
    _pause.paused = _paused;
    _pause.accessibilityLabel = _paused ? @"Play" : @"Pause";
    [_pause setNeedsDisplay];
}
- (void)togglePause {
    if (!_item) return;
    _paused = !_paused;
    if (_paused) [_player pause];
    else {
        _lastProgress = NSDate.date;
        [_player play];
    }
    [self updatePause];
    [self setControlsVisible:YES];
}
- (void)showToast:(NSString *)text {
    _toast.text = text;
    _toast.hidden = NO;
    _toastUntil = [NSDate dateWithTimeIntervalSinceNow:1.5];
}
- (void)swipe:(UISwipeGestureRecognizer *)gesture {
    if (_games.count < 2) return;
    if (gesture.direction == UISwipeGestureRecognizerDirectionLeft) _gameIndex = (_gameIndex + 1) % _games.count;
    else _gameIndex = (_gameIndex + _games.count - 1) % _games.count;
    [self selectGame];
    [self showToast:[NSString stringWithFormat:@"%@\n%@", _titleLabel.text, _networkLabel.text]];
}
- (void)cancelInteractions {
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        gesture.enabled = NO;
        gesture.enabled = YES;
    }
    [_volume endEditing:YES];
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self cancelInteractions];
    [self setControlsVisible:YES];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}
- (void)backgrounded {
    [self cancelInteractions];
    _background = YES;
    _hideAt = nil;
    _toast.hidden = YES;
    [self stopItem];
}
- (void)foregrounded {
    if (!_background || _closed) return;
    _background = NO;
    if (![self.game.state isEqualToString:@"pre"]) [self startFeed];
    [self setControlsVisible:YES];
}
- (void)closeTapped {
    [self tearDown];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.presentingViewController == nil) [self tearDown];
}
- (void)tearDown {
    if (_closed) return;
    _closed = YES;
    [_timer invalidate];
    _timer = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self stopItem];
}
- (void)dealloc {
    [_timer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self stopItem];
}
@end
