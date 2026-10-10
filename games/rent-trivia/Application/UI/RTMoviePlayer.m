#import "RTMoviePlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "../Game/RTMovieStream.h"

static NSString *const RTKeyDefault = @"movie.apiKey";
static NSString *const RTPositionDefault = @"movie.position";
static NSString *const RTDurationDefault = @"movie.duration";

// AVPlayerViewController observes KVO itself on iOS 10, so ours needs its own context.
static void *RTStatusContext = &RTStatusContext;

@class RTPlayerController;
static RTPlayerController *RTCurrentPlayer;

@interface RTPlayerController : AVPlayerViewController
@property(nonatomic, strong) RTMovieStream *stream;
@property(nonatomic, weak) UIViewController *presenter;
@property(nonatomic) double startAt;
@end

@implementation RTPlayerController {
    id _timeObserver;
    BOOL _started, _failed;
}

- (void)start {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.stream.playlistURL options:@{@"AVURLAssetHTTPHeaderFieldsKey": self.stream.headers}];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    [item addObserver:self forKeyPath:@"status" options:0 context:RTStatusContext];
    self.player = [AVPlayer playerWithPlayerItem:item];
    __weak typeof(self) weakSelf = self;
    _timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(5, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf savePosition];
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != RTStatusContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    AVPlayerItem *item = object;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (item.status == AVPlayerItemStatusReadyToPlay && !self->_started) {
            self->_started = YES;
            if (self.startAt > 0) [self.player seekToTime:CMTimeMakeWithSeconds(self.startAt, 600)];
            [self.player play];
        } else if (item.status == AVPlayerItemStatusFailed && !self->_failed) {
            self->_failed = YES;
            [self failWith:item.error];
        }
    });
}

- (void)failWith:(NSError *)error {
    NSLog(@"Movie stream failed: %@", error);
    UIViewController *presenter = self.presenter;
    [self dismissViewControllerAnimated:YES completion:^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Can't reach TIMTV"
                                                                        message:@"Make sure the server is up and the iPad is online. If the API key changed, enter the new one."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Change API Key" style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) { [RTMoviePlayer editKeyFrom:presenter]; }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Try Again" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [RTMoviePlayer playFrom:presenter]; }]];
        [presenter presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)savePosition {
    if (!_started || _failed) return;
    double t = CMTimeGetSeconds(self.player.currentTime);
    double d = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(t)) return;
    NSUserDefaults *u = NSUserDefaults.standardUserDefaults;
    if (isfinite(d) && d > 0) [u setDouble:d forKey:RTDurationDefault];
    // Finishing the film clears the resume point.
    if (isfinite(d) && d > 0 && t > d - 300) [u removeObjectForKey:RTPositionDefault];
    else [u setDouble:t forKey:RTPositionDefault];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (!self.isBeingDismissed) return;
    [self savePosition];
    [self tearDown];
}

- (void)tearDown {
    if (!self.player) return;
    [self.player pause];
    if (_timeObserver) [self.player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
    [self.player.currentItem removeObserver:self forKeyPath:@"status" context:RTStatusContext];
    self.player = nil;
    // Ends the server-side transcode instead of leaving ffmpeg running on the NAS.
    NSMutableURLRequest *stop = [NSMutableURLRequest requestWithURL:self.stream.stopURL];
    stop.HTTPMethod = @"DELETE";
    [self.stream.headers enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *s) { [stop setValue:v forHTTPHeaderField:k]; }];
    [[[NSURLSession sharedSession] dataTaskWithRequest:stop] resume];
    if (RTCurrentPlayer == self) RTCurrentPlayer = nil;
}
@end

@implementation RTMoviePlayer

+ (NSDictionary *)config {
    return [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Jellyfin" ofType:@"plist"]] ?: @{};
}

+ (NSString *)apiKey {
    NSString *saved = [NSUserDefaults.standardUserDefaults stringForKey:RTKeyDefault];
    return saved.length ? saved : self.config[@"ApiKey"];
}

+ (void)playFrom:(UIViewController *)presenter {
    if (![self.config[@"Server"] length] || ![self.config[@"ItemId"] length]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Movie not set up"
                                                                        message:@"Add Resources/Jellyfin.plist (see Jellyfin.example.plist) and rebuild."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSUserDefaults *u = NSUserDefaults.standardUserDefaults;
    double position = [u doubleForKey:RTPositionDefault], duration = [u doubleForKey:RTDurationDefault];
    if (![RTMovieStream shouldOfferResumeAt:position duration:duration]) {
        [self playFrom:presenter at:0];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rent (2005)" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[@"Resume from " stringByAppendingString:[RTMovieStream formatTime:position]] style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { [self playFrom:presenter at:position]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Start Over" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self playFrom:presenter at:0]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

+ (void)playFrom:(UIViewController *)presenter at:(double)start {
    NSDictionary *c = self.config;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:NULL];
    RTPlayerController *player = [RTPlayerController new];
    player.stream = [[RTMovieStream alloc] initWithServer:c[@"Server"] itemId:c[@"ItemId"] apiKey:self.apiKey];
    player.presenter = presenter;
    player.startAt = start;
    RTCurrentPlayer = player;
    [presenter presentViewController:player animated:YES completion:^{ [player start]; }];
}

+ (void)editKeyFrom:(UIViewController *)presenter {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Jellyfin API Key" message:@"Dashboard → API Keys on TIMTV." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = self.apiKey;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.clearButtonMode = UITextFieldViewModeAlways;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *key = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (key.length && ![key isEqualToString:self.config[@"ApiKey"]]) [NSUserDefaults.standardUserDefaults setObject:key forKey:RTKeyDefault];
        else [NSUserDefaults.standardUserDefaults removeObjectForKey:RTKeyDefault];
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}
@end
