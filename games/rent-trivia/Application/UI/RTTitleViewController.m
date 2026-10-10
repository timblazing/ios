#import "RTTitleViewController.h"
#import "RTStyle.h"
#import "RTQuizViewController.h"
#import "RTCastViewController.h"
#import "RTMoviePlayer.h"

@implementation RTTitleViewController {
    RTBackdropView *_hero;
    CAGradientLayer *_fade;
    UIImageView *_logo;
    UILabel *_subtitle, *_tagline, *_best;
    RTTileButton *_quick, *_full, *_cast, *_movie;
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1];

    _hero = [RTBackdropView new];
    _hero.dim = 0.08;
    [_hero showImageNamed:@"cast-bands" animated:NO];
    [self.view addSubview:_hero];
    _fade = [CAGradientLayer layer];
    _fade.colors = @[(id)[UIColor colorWithWhite:0.04 alpha:0].CGColor, (id)[UIColor colorWithWhite:0.04 alpha:1].CGColor];
    [self.view.layer addSublayer:_fade];

    _logo = [[UIImageView alloc] initWithImage:RTStyle.logo];
    _logo.contentMode = UIViewContentModeScaleAspectFit;
    _logo.layer.shadowColor = UIColor.blackColor.CGColor;
    _logo.layer.shadowOpacity = 0.8;
    _logo.layer.shadowRadius = 10;
    _logo.layer.shadowOffset = CGSizeMake(0, 6);
    _logo.isAccessibilityElement = YES;
    _logo.accessibilityLabel = @"Rent";
    [self.view addSubview:_logo];

    _subtitle = [UILabel new];
    _subtitle.attributedText = [RTStyle spaced:@"THE TRIVIA GAME" font:[RTStyle stencil:26] color:UIColor.whiteColor kern:6];
    _subtitle.textAlignment = NSTextAlignmentCenter;
    _subtitle.backgroundColor = RTStyle.red;
    _subtitle.transform = CGAffineTransformMakeRotation(-0.025);
    [self.view addSubview:_subtitle];

    _tagline = [UILabel new];
    _tagline.attributedText = [RTStyle spaced:@"No day but today." font:[RTStyle type:19] color:[UIColor colorWithWhite:1 alpha:0.75] kern:1.5];
    _tagline.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_tagline];

    _quick = [RTTileButton tileWithTitle:@"PLAY\n10 QUESTIONS" color:RTStyle.orange];
    _full = [RTTileButton tileWithTitle:@"THE FULL YEAR\n25 QUESTIONS" color:RTStyle.blue];
    _cast = [RTTileButton tileWithTitle:@"MEET\nTHE CAST" color:RTStyle.green];
    _quick.tilt = -0.02;
    _full.tilt = 0.015;
    _cast.tilt = -0.01;
    _movie = [RTTileButton tileWithTitle:@"WATCH\nTHE MOVIE" color:RTStyle.red];
    _movie.tilt = 0.02;
    _movie.accessibilityHint = @"Streams Rent from TIMTV. Press and hold to change the API key.";
    [_movie addTarget:self action:@selector(watchMovie) forControlEvents:UIControlEventTouchUpInside];
    [_movie addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(editKey:)]];
    [_quick addTarget:self action:@selector(playQuick) forControlEvents:UIControlEventTouchUpInside];
    [_full addTarget:self action:@selector(playFull) forControlEvents:UIControlEventTouchUpInside];
    [_cast addTarget:self action:@selector(showCast) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *v in @[_quick, _full, _cast, _movie]) [self.view addSubview:v];

    _best = [UILabel new];
    _best.textAlignment = NSTextAlignmentCenter;
    _best.numberOfLines = 1;
    [self.view addSubview:_best];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *parts = [NSMutableArray array];
    for (NSNumber *n in @[@10, @25]) {
        NSString *key = [NSString stringWithFormat:@"best.%@", n];
        if ([d objectForKey:key]) [parts addObject:[NSString stringWithFormat:@"%@ questions: %ld/%@", n, (long)[d integerForKey:key], n]];
    }
    NSString *text = parts.count ? [@"Best  ·  " stringByAppendingString:[parts componentsJoinedByString:@"  ·  "]] : @"525,600 minutes of Rent. How well do you know it?";
    _best.attributedText = [RTStyle spaced:text font:[RTStyle type:16] color:[UIColor colorWithWhite:1 alpha:0.55] kern:0.5];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_hero startDrift];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize s = self.view.bounds.size;
    BOOL portrait = s.height > s.width;
    CGFloat heroH = round(s.height * (portrait ? 0.5 : 0.6));
    _hero.frame = CGRectMake(0, 0, s.width, heroH);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fade.frame = CGRectMake(0, heroH * 0.45, s.width, heroH * 0.55 + 1);
    [CATransaction commit];

    CGFloat logoW = MIN(portrait ? s.width * 0.8 : 560, s.width - 80);
    CGSize img = RTStyle.logo.size;
    CGFloat logoH = img.width > 0 ? logoW * img.height / img.width : 0;
    CGFloat logoY = heroH - logoH * 0.75;
    _logo.frame = CGRectMake((s.width - logoW) / 2, logoY, logoW, logoH);

    CGSize sub = [_subtitle.attributedText size];
    RTPlace(_subtitle, CGRectMake((s.width - sub.width - 36) / 2, CGRectGetMaxY(_logo.frame) + 14, sub.width + 36, 40));
    _tagline.frame = CGRectMake(20, CGRectGetMaxY(_logo.frame) + 62, s.width - 40, 26);

    CGFloat top = CGRectGetMaxY(_tagline.frame) + (portrait ? 40 : 26);
    NSArray *tiles = @[_quick, _full, _cast, _movie];
    if (portrait) {
        // Two by two, so four tiles still fit under the logo on a 1024pt-tall screen.
        CGFloat gap = 22, w = MIN(260, (s.width - 100 - gap) / 2), h = 80, x = (s.width - 2 * w - gap) / 2;
        for (NSUInteger i = 0; i < tiles.count; i++) RTPlace(tiles[i], CGRectMake(x + (i % 2) * (w + gap), top + (i / 2) * (h + gap), w, h));
    } else {
        CGFloat gap = 24, w = MIN(220, (s.width - 80 - 3 * gap) / 4), h = 84, x = (s.width - 4 * w - 3 * gap) / 2;
        for (NSUInteger i = 0; i < tiles.count; i++) RTPlace(tiles[i], CGRectMake(x + i * (w + gap), top, w, h));
    }
    _best.frame = CGRectMake(20, s.height - 44, s.width - 40, 24);
}

- (void)playQuick { RTShowScreen([[RTQuizViewController alloc] initWithCount:10]); }
- (void)playFull { RTShowScreen([[RTQuizViewController alloc] initWithCount:25]); }
- (void)showCast { RTShowScreen([RTCastViewController new]); }
- (void)watchMovie { [RTMoviePlayer playFrom:self]; }
- (void)editKey:(UILongPressGestureRecognizer *)press {
    if (press.state != UIGestureRecognizerStateBegan) return;
    _movie.highlighted = NO;
    [RTMoviePlayer editKeyFrom:self];
}
@end
