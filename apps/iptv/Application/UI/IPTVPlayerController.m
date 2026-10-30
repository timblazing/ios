#import "IPTVPlayerController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

static void *IPTVStatusContext = &IPTVStatusContext;
static void *IPTVPictureContext = &IPTVPictureContext;

static UIImage *IPTVAirPlayImage(void) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(26, 26), NO, 0);
    [UIColor.whiteColor setStroke]; [UIColor.whiteColor setFill];
    UIBezierPath *screen = [UIBezierPath bezierPath]; screen.lineWidth = 1.8; screen.lineJoinStyle = kCGLineJoinRound;
    [screen moveToPoint:CGPointMake(7, 19)]; [screen addLineToPoint:CGPointMake(3, 19)];
    [screen addLineToPoint:CGPointMake(3, 5)]; [screen addLineToPoint:CGPointMake(23, 5)];
    [screen addLineToPoint:CGPointMake(23, 19)]; [screen addLineToPoint:CGPointMake(19, 19)]; [screen stroke];
    UIBezierPath *arrow = [UIBezierPath bezierPath];
    [arrow moveToPoint:CGPointMake(13, 16)]; [arrow addLineToPoint:CGPointMake(20, 24)];
    [arrow addLineToPoint:CGPointMake(6, 24)]; [arrow closePath]; [arrow fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image;
}

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
    UILabel *_titleLabel, *_message, *_toast;
    MPVolumeView *_volume, *_airplay;
    UIImageView *_airplayUnavailable;
    UIActivityIndicatorView *_spinner;
    NSTimer *_timer, *_hideTimer;
    NSDate *_toastUntil, *_lastProgress;
    double _lastTime;
    BOOL _paused, _background, _closed, _exhausted, _hasPicture;
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
    [_video addObserver:self forKeyPath:@"readyForDisplay" options:0 context:IPTVPictureContext];
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
    [_top addSubview:_titleLabel];
    UIImage *airplayImage = IPTVAirPlayImage();
    _airplayUnavailable = [[UIImageView alloc] initWithImage:airplayImage];
    _airplayUnavailable.contentMode = UIViewContentModeCenter; _airplayUnavailable.alpha = 0.35;
    _airplayUnavailable.isAccessibilityElement = YES; _airplayUnavailable.accessibilityLabel = @"AirPlay unavailable";
    [_top addSubview:_airplayUnavailable];
    _airplay = [MPVolumeView new];
    _airplay.showsRouteButton = YES;
    _airplay.showsVolumeSlider = NO;
    _airplay.tintColor = UIColor.whiteColor;
    _airplay.accessibilityLabel = @"AirPlay";
    [_airplay setRouteButtonImage:airplayImage forState:UIControlStateNormal];
    [_top addSubview:_airplay];
    _pause = [IPTVPlayerButton buttonWithType:UIButtonTypeCustom];
    _pause.accessibilityLabel = @"Pause";
    [_pause addTarget:self action:@selector(togglePause) forControlEvents:UIControlEventTouchUpInside];
    [_bottom addSubview:_pause];
    _volume = [MPVolumeView new];
    _volume.showsRouteButton = NO;
    _volume.showsVolumeSlider = YES;
    _volume.tintColor = UIColor.whiteColor;
    _volume.accessibilityLabel = @"Volume";
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
    _titleLabel.frame = CGRectMake(80, 24, w - 160, 44);
    _airplay.frame = CGRectMake(w - 60, 24, 44, 44);
    _airplayUnavailable.frame = _airplay.frame;
    _airplayUnavailable.hidden = _airplay.areWirelessRoutesAvailable || _airplay.isWirelessRouteActive;
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
    [_hideTimer invalidate]; _hideTimer = nil;
    _chrome.userInteractionEnabled = visible;
#if TARGET_OS_SIMULATOR
    NSLog(@"TV controls visible=%d picture=%d", visible, _hasPicture);
#endif
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.2 animations:^{ self->_chrome.alpha = visible ? 1 : 0; }];
    if (visible && _hasPicture && !_paused && !_exhausted && !UIAccessibilityIsVoiceOverRunning()) {
        __weak typeof(self) weakSelf = self;
        _hideTimer = [NSTimer timerWithTimeInterval:2.5 repeats:NO block:^(NSTimer *timer) {
            typeof(self) self = weakSelf;
            if (self && !self->_closed && !self->_background && self->_hasPicture && self->_item &&
                !self->_paused && !self->_exhausted && !UIAccessibilityIsVoiceOverRunning()) [self setControlsVisible:NO];
        }];
        [NSRunLoop.mainRunLoop addTimer:_hideTimer forMode:NSRunLoopCommonModes];
    }
}
- (void)pictureStarted {
    if (!_hasPicture && !_closed && !_background && _item.status == AVPlayerItemStatusReadyToPlay &&
        _video.readyForDisplay && _player.rate > 0) {
        _hasPicture = YES;
        [_spinner stopAnimating];
        [self setControlsVisible:YES];
#if TARGET_OS_SIMULATOR
        NSLog(@"TV first picture: controls hide in 2.5 seconds");
#endif
    }
}
- (void)toggleControls { [self setControlsVisible:!_hasPicture || _chrome.alpha < 0.5]; }
- (void)selectGame {
    [self stopItem];
    _feedIndex = 0;
    _exhausted = NO;
    _paused = NO;
    IPTVGame *game = self.game;
    if (game) {
        _channel = game.channels.firstObject;
        _titleLabel.text = [NSString stringWithFormat:@"%@ @ %@", game.away.nick.length ? game.away.nick : game.away.name, game.home.nick.length ? game.home.nick : game.home.name];
    } else _titleLabel.text = _channel.name;
    [self setControlsVisible:YES];
    if ([game.state isEqualToString:@"pre"]) {
        NSDateFormatter *date = [NSDateFormatter new];
        date.dateStyle = NSDateFormatterMediumStyle;
        date.timeStyle = NSDateFormatterShortStyle;
        _message.text = [NSString stringWithFormat:@"Starts %@", game.start ? [date stringFromDate:game.start] : game.detail];
        _pause.hidden = YES;
        return;
    }
    _pause.hidden = NO;
    [self startFeed];
}
- (void)startFeed {
    [self stopItem];
    if (_closed || _background) return;
    _message.text = nil;
    _exhausted = NO;
    [self setControlsVisible:YES];
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
    [_hideTimer invalidate]; _hideTimer = nil;
    _hasPicture = NO;
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
    if (context == IPTVPictureContext) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf pictureStarted]; });
        return;
    }
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
    _airplayUnavailable.hidden = _airplay.areWirelessRoutesAvailable || _airplay.isWirelessRouteActive;
    if (_toastUntil && [now compare:_toastUntil] != NSOrderedAscending) { _toast.hidden = YES; _toastUntil = nil; }
    if (!_item) return;
    [self pictureStarted];
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
        if (_hasPicture) [_spinner stopAnimating];
    }
    if (!_paused && [now timeIntervalSinceDate:_lastProgress] > 20) { [self feedFailed]; return; }
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
    [self showToast:_titleLabel.text];
}
- (void)cancelInteractions {
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        gesture.enabled = NO;
        gesture.enabled = YES;
    }
    [_volume endEditing:YES];
    [_airplay endEditing:YES];
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self cancelInteractions];
    [self setControlsVisible:YES];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}
- (void)backgrounded {
    [self cancelInteractions];
    _background = YES;
    [_hideTimer invalidate]; _hideTimer = nil;
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
    [_video removeObserver:self forKeyPath:@"readyForDisplay" context:IPTVPictureContext];
    [_hideTimer invalidate];
    [_timer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self stopItem];
}
@end
