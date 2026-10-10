#import "RTResultsViewController.h"
#import "RTStyle.h"
#import "RTQuizViewController.h"
#import "RTTitleViewController.h"
#import "../Game/RTRound.h"

@implementation RTResultsViewController {
    NSUInteger _correct, _count, _bestStreak;
    NSArray<NSNumber *> *_results;
    BOOL _newBest;
    NSInteger _target;
    NSTimer *_tick;

    RTBackdropView *_backdrop;
    UILabel *_caption, *_number, *_of, *_title, *_blurb, *_stats;
    NSMutableArray<UIView *> *_dots;
    RTTileButton *_again, *_menu;
}

- (instancetype)initWithCorrect:(NSUInteger)correct of:(NSUInteger)count bestStreak:(NSUInteger)bestStreak results:(NSArray<NSNumber *> *)results {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _correct = correct;
        _count = count;
        _bestStreak = bestStreak;
        _results = [results copy];
        _target = [RTRound minutesForCorrect:correct of:count];
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        NSString *key = [NSString stringWithFormat:@"best.%lu", (unsigned long)count];
        _newBest = [d objectForKey:key] == nil || (NSInteger)correct > [d integerForKey:key];
        if (_newBest) [d setInteger:correct forKey:key];
    }
    return self;
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    _backdrop = [RTBackdropView new];
    _backdrop.dim = 0.5;
    [_backdrop showImageNamed:@"seasons-stage" animated:NO];
    [self.view addSubview:_backdrop];

    _caption = [self label:[RTStyle spaced:@"HOW DO YOU MEASURE A YEAR?" font:[RTStyle typeBold:18] color:[UIColor colorWithWhite:1 alpha:0.75] kern:3]];
    _number = [self label:nil];
    _of = [self label:[RTStyle spaced:@"OF 525,600 MINUTES" font:[RTStyle type:20] color:[UIColor colorWithWhite:1 alpha:0.6] kern:2]];

    NSString *rating = [RTRound titleForCorrect:_correct of:_count];
    _title = [self label:[RTStyle spaced:rating font:[RTStyle stencil:52] color:UIColor.whiteColor kern:3]];
    double p = _count ? (double)_correct / _count : 0;
    _title.backgroundColor = p >= 1 ? RTStyle.yellow : p >= 0.8 ? RTStyle.green : p >= 0.6 ? RTStyle.blue : p >= 0.4 ? RTStyle.orange : RTStyle.red;
    if (p >= 1) _title.attributedText = [RTStyle spaced:rating font:[RTStyle stencil:52] color:RTStyle.ink kern:3];
    _title.layer.shadowColor = UIColor.blackColor.CGColor;
    _title.layer.shadowOpacity = 0.6;
    _title.layer.shadowRadius = 10;
    _title.layer.shadowOffset = CGSizeMake(0, 6);

    _blurb = [self label:[RTStyle spaced:[RTRound blurbForCorrect:_correct of:_count] font:[RTStyle type:22] color:UIColor.whiteColor kern:0.3]];
    _blurb.numberOfLines = 0;

    NSMutableAttributedString *stats = [[RTStyle spaced:[NSString stringWithFormat:@"%lu of %lu right  ·  best streak %lu", (unsigned long)_correct, (unsigned long)_count, (unsigned long)_bestStreak]
                                                   font:[RTStyle typeBold:18] color:[UIColor colorWithWhite:1 alpha:0.8] kern:1] mutableCopy];
    if (_newBest && _correct > 0) [stats appendAttributedString:[RTStyle spaced:@"  ·  NEW BEST!" font:[RTStyle typeBold:18] color:RTStyle.yellow kern:1]];
    _stats = [self label:stats];

    _dots = [NSMutableArray array];
    for (NSNumber *r in _results) {
        UIView *dot = [UIView new];
        dot.backgroundColor = r.boolValue ? RTStyle.green : RTStyle.red;
        [_dots addObject:dot];
        [self.view addSubview:dot];
    }

    _again = [RTTileButton tileWithTitle:@"PLAY AGAIN" color:RTStyle.orange];
    _menu = [RTTileButton tileWithTitle:@"MENU" color:RTStyle.blue];
    _again.tilt = -0.02;
    _menu.tilt = 0.015;
    [_again addTarget:self action:@selector(playAgain) forControlEvents:UIControlEventTouchUpInside];
    [_menu addTarget:self action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_again];
    [self.view addSubview:_menu];

    [self renderNumber:RTStyle.reduceMotion ? _target : 0];
}

- (UILabel *)label:(NSAttributedString *)text {
    UILabel *l = [UILabel new];
    l.attributedText = text;
    l.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:l];
    return l;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_backdrop startDrift];
    if (RTStyle.reduceMotion || _target == 0) return;
    CFTimeInterval start = CACurrentMediaTime();
    __weak typeof(self) weakSelf = self;
    _tick = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30 repeats:YES block:^(NSTimer *timer) {
        typeof(self) me = weakSelf;
        if (!me) { [timer invalidate]; return; }
        double t = MIN(1, (CACurrentMediaTime() - start) / 2.2);
        [me renderNumber:(NSInteger)llround(me->_target * (1 - pow(1 - t, 3)))];
        if (t >= 1) [timer invalidate];
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_tick invalidate];
}

- (void)renderNumber:(NSInteger)n {
    NSNumberFormatter *f = [NSNumberFormatter new];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [UIColor colorWithWhite:0 alpha:0.7];
    shadow.shadowBlurRadius = 16;
    shadow.shadowOffset = CGSizeMake(0, 4);
    _number.attributedText = [[NSAttributedString alloc] initWithString:[f stringFromNumber:@(n)]
                                                             attributes:@{NSFontAttributeName: [RTStyle stencil:140], NSForegroundColorAttributeName: UIColor.whiteColor,
                                                                          NSKernAttributeName: @4, NSShadowAttributeName: shadow}];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize s = self.view.bounds.size;
    BOOL portrait = s.height > s.width;
    CGFloat y = portrait ? 120 : 52;
    _backdrop.frame = self.view.bounds;
    _caption.frame = CGRectMake(20, y, s.width - 40, 26);
    _number.frame = CGRectMake(20, y + 30, s.width - 40, 150);
    _of.frame = CGRectMake(20, y + 182, s.width - 40, 26);

    CGSize t = [_title.attributedText size];
    RTPlace(_title, CGRectMake((s.width - t.width - 60) / 2, y + 240, t.width + 60, 76));
    _title.transform = CGAffineTransformMakeRotation(-0.025);

    CGFloat bw = MIN(640, s.width - 80);
    CGFloat bh = ceil([_blurb.attributedText boundingRectWithSize:CGSizeMake(bw, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height);
    _blurb.frame = CGRectMake((s.width - bw) / 2, y + 344, bw, bh);
    _stats.frame = CGRectMake(20, CGRectGetMaxY(_blurb.frame) + 14, s.width - 40, 24);

    CGFloat d = _dots.count > 15 ? 14 : 18, gap = 6, rowW = _dots.count * d + (_dots.count ? (_dots.count - 1) * gap : 0);
    for (NSUInteger i = 0; i < _dots.count; i++) _dots[i].frame = CGRectMake((s.width - rowW) / 2 + i * (d + gap), CGRectGetMaxY(_stats.frame) + 16, d, d);

    CGFloat w = 240, h = 72, by = s.height - h - (portrait ? 120 : 48);
    RTPlace(_again, CGRectMake(s.width / 2 - w - 15, by, w, h));
    RTPlace(_menu, CGRectMake(s.width / 2 + 15, by, w, h));
}

- (void)playAgain { RTShowScreen([[RTQuizViewController alloc] initWithCount:_count]); }
- (void)showMenu { RTShowScreen([RTTitleViewController new]); }
@end
