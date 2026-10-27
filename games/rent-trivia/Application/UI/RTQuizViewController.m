#import "RTQuizViewController.h"
#import "RTStyle.h"
#import "RTResultsViewController.h"
#import "RTTitleViewController.h"
#import "../Game/RTRound.h"

static NSArray<RTQuestion *> *RTAllQuestions(void) {
    static NSArray *all;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        all = [RTQuestion questionsFromJSONData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Questions" ofType:@"json"]]];
    });
    return all;
}

@implementation RTQuizViewController {
    NSUInteger _count;
    RTRound *_round;
    NSMutableArray<NSNumber *> *_results;  // per question: @YES right, @NO wrong
    NSInteger _shownMinutes;
    NSTimer *_tick;

    RTBackdropView *_backdrop;
    UIButton *_close;
    UIImageView *_logo;
    UILabel *_progress, *_minutesCaption, *_minutes, *_streak;
    NSMutableArray<UIView *> *_segments;
    RTPaperView *_card;
    RTPolaroidView *_polaroid;
    UILabel *_question, *_feedback, *_fact;
    NSArray<RTTileButton *> *_tiles;
    RTTileButton *_next;
}

- (instancetype)initWithCount:(NSUInteger)count {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _count = count;
        _round = [[RTRound alloc] initWithQuestions:RTAllQuestions() count:count random:nil];
        _results = [NSMutableArray array];
    }
    return self;
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    _backdrop = [RTBackdropView new];
    _backdrop.dim = 0.66;
    [self.view addSubview:_backdrop];

    _close = [UIButton buttonWithType:UIButtonTypeCustom];
    [_close setAttributedTitle:[RTStyle spaced:@"✕" font:[RTStyle stencil:26] color:[UIColor colorWithWhite:1 alpha:0.85] kern:0] forState:UIControlStateNormal];
    _close.accessibilityLabel = @"Quit round";
    [_close addTarget:self action:@selector(confirmQuit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_close];

    _logo = [[UIImageView alloc] initWithImage:RTStyle.logo];
    _logo.contentMode = UIViewContentModeScaleAspectFit;
    _logo.alpha = 0.95;
    [self.view addSubview:_logo];

    _progress = [UILabel new];
    _minutesCaption = [UILabel new];
    _minutesCaption.attributedText = [RTStyle spaced:@"MINUTES" font:[RTStyle type:13] color:[UIColor colorWithWhite:1 alpha:0.6] kern:2];
    _minutesCaption.textAlignment = NSTextAlignmentRight;
    _minutes = [UILabel new];
    _minutes.textAlignment = NSTextAlignmentRight;
    _streak = [UILabel new];
    _streak.textAlignment = NSTextAlignmentCenter;
    _streak.backgroundColor = RTStyle.yellow;
    _streak.alpha = 0;
    for (UIView *v in @[_progress, _minutesCaption, _minutes, _streak]) [self.view addSubview:v];

    _segments = [NSMutableArray array];
    for (NSUInteger i = 0; i < _round.count; i++) {
        UIView *seg = [UIView new];
        [_segments addObject:seg];
        [self.view addSubview:seg];
    }

    _card = [RTPaperView new];
    [self.view addSubview:_card];
    _polaroid = [RTPolaroidView new];
    [_card addSubview:_polaroid];
    _question = [UILabel new];
    _question.numberOfLines = 0;
    _question.textColor = RTStyle.ink;
    _feedback = [UILabel new];
    _fact = [UILabel new];
    _fact.numberOfLines = 0;
    for (UIView *v in @[_question, _feedback, _fact]) [_card addSubview:v];

    NSMutableArray *tiles = [NSMutableArray array];
    for (NSUInteger i = 0; i < 4; i++) {
        RTTileButton *t = [RTTileButton tileWithTitle:@"" color:[RTStyle bandColor:i]];
        t.tag = i;
        t.tilt = (i % 2 ? 0.012 : -0.012) * (i < 2 ? 1 : -1);
        [t addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];
        [tiles addObject:t];
        [self.view addSubview:t];
    }
    _tiles = tiles;

    _next = [RTTileButton tileWithTitle:@"NEXT  ›" color:RTStyle.yellow];
    [_next setTitleColor:RTStyle.ink forState:UIControlStateNormal];
    [_next setTitleShadowColor:UIColor.clearColor forState:UIControlStateNormal];
    _next.tilt = 0.02;
    [_next addTarget:self action:@selector(advance) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_next];

    [self updateMinutes:NO];
    [self showQuestion];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_tick invalidate];
}

#pragma mark - Question flow

- (void)showQuestion {
    RTQuestion *q = _round.question;
    [_backdrop showImageNamed:q.backdrop ?: @"collage" animated:YES];

    _progress.attributedText = [RTStyle spaced:[NSString stringWithFormat:@"QUESTION %lu OF %lu", (unsigned long)_round.index + 1, (unsigned long)_round.count]
                                          font:[RTStyle stencil:22] color:UIColor.whiteColor kern:2];
    _feedback.alpha = 0;
    _fact.alpha = 0;
    _next.alpha = 0;
    _next.userInteractionEnabled = NO;

    _polaroid.hidden = q.image == nil;
    _polaroid.imageView.image = nil;
    if (q.image) {
        _polaroid.imageView.image = [RTStyle imageNamed:q.image];  // usually already preloaded
        _polaroid.transform = CGAffineTransformMakeRotation(_round.index % 2 ? 0.035 : -0.035);
    }

    for (RTTileButton *t in _tiles) {
        NSUInteger i = t.tag;
        BOOL used = i < _round.answers.count;
        t.hidden = !used;
        t.enabled = used;
        t.alpha = 1;
        t.tileColor = [RTStyle bandColor:i];
        t.layer.borderWidth = 2;
        t.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
        NSString *title = used ? [_round.answers[i] uppercaseString] : @"";
        [t setTitle:title forState:UIControlStateNormal];
        [t setTitle:title forState:UIControlStateDisabled];
        [t setTitleColor:[UIColor colorWithWhite:1 alpha:0.9] forState:UIControlStateDisabled];
    }
    [self updateSegments];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];

    RTQuestion *upcoming = _round.nextQuestion;
    [RTStyle loadImageNamed:upcoming.backdrop ?: @"collage" completion:nil];
    if (upcoming.image) [RTStyle loadImageNamed:upcoming.image completion:nil];
}

- (CGFloat)heightOf:(NSAttributedString *)text width:(CGFloat)width {
    return ceil([text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height);
}

- (NSAttributedString *)questionText:(NSString *)text size:(CGFloat)size {
    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
    p.lineSpacing = 4;
    return [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: [RTStyle typeBold:size], NSForegroundColorAttributeName: RTStyle.ink, NSParagraphStyleAttributeName: p}];
}

- (void)choose:(RTTileButton *)tile {
    if (_round.isAnswered) return;
    NSUInteger correct = _round.correctIndex;
    BOOL right = [_round answer:tile.tag];
    [_results addObject:@(right)];

    for (RTTileButton *t in _tiles) t.enabled = NO;
    RTTileButton *answer = _tiles[correct];
    [answer setTitle:[@"✓  " stringByAppendingString:[_round.answers[correct] uppercaseString]] forState:UIControlStateDisabled];
    [answer setTitleColor:UIColor.whiteColor forState:UIControlStateDisabled];
    if (!right) [tile setTitle:[@"✕  " stringByAppendingString:[_round.answers[tile.tag] uppercaseString]] forState:UIControlStateDisabled];
    [UIView animateWithDuration:0.25 animations:^{
        for (RTTileButton *t in self->_tiles) {
            if (t == answer) continue;
            t.alpha = t == tile ? 0.75 : 0.25;
        }
        answer.layer.borderColor = UIColor.whiteColor.CGColor;
    }];
    answer.layer.borderWidth = 5;
    if (right) [self pop:answer];
    else [self shake:tile];

    NSArray *cheers = @[@"RIGHT ON!", @"BRAVO!", @"VIVA LA VIE BOHÈME!", @"YOU GOT IT!", @"THAT'S THE ONE!"];
    NSString *head = right ? cheers[arc4random_uniform((uint32_t)cheers.count)] : @"NOT QUITE.";
    _feedback.attributedText = [RTStyle spaced:head font:[RTStyle stencil:30] color:right ? RTStyle.green : RTStyle.red kern:1.5];

    NSMutableAttributedString *fact = [NSMutableAttributedString new];
    NSDictionary *plain = @{NSFontAttributeName: [RTStyle type:20], NSForegroundColorAttributeName: [RTStyle.ink colorWithAlphaComponent:0.85]};
    if (!right) {
        [fact appendAttributedString:[[NSAttributedString alloc] initWithString:@"It's " attributes:plain]];
        [fact appendAttributedString:[[NSAttributedString alloc] initWithString:_round.answers[correct] attributes:@{NSFontAttributeName: [RTStyle typeBold:20], NSForegroundColorAttributeName: RTStyle.ink}]];
        [fact appendAttributedString:[[NSAttributedString alloc] initWithString:@". " attributes:plain]];
    }
    [fact appendAttributedString:[[NSAttributedString alloc] initWithString:_round.question.fact attributes:plain]];
    _fact.attributedText = fact;

    [_next setTitle:_round.index + 1 >= _round.count ? @"FINAL CURTAIN  ›" : @"NEXT  ›" forState:UIControlStateNormal];
    _next.userInteractionEnabled = YES;

    [self updateSegments];
    [self updateMinutes:YES];
    [self updateStreak];
    [self.view setNeedsLayout];
    [UIView animateWithDuration:RTStyle.reduceMotion ? 0 : 0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self.view layoutIfNeeded];
        self->_feedback.alpha = 1;
        self->_fact.alpha = 1;
        self->_next.alpha = 1;
    } completion:nil];
}

- (void)advance {
    _next.userInteractionEnabled = NO;
    if (![_round advance]) {
        RTShowScreen([[RTResultsViewController alloc] initWithCorrect:_round.correctCount of:_round.count bestStreak:_round.bestStreak results:_results]);
        return;
    }
    if (RTStyle.reduceMotion) {
        [self showQuestion];
        return;
    }
    NSArray *moving = [@[_card] arrayByAddingObjectsFromArray:_tiles];
    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        for (UIView *v in moving) { v.alpha = 0; v.center = CGPointMake(v.center.x - 60, v.center.y); }
        self->_next.alpha = 0;
    } completion:^(BOOL done) {
        [self showQuestion];
        for (UIView *v in moving) { v.alpha = 0; v.center = CGPointMake(v.center.x + 60, v.center.y); }
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:0 animations:^{
            for (UIView *v in moving) { v.alpha = 1; v.center = CGPointMake(v.center.x - 60, v.center.y); }
        } completion:nil];
    }];
}

#pragma mark - Score chrome

- (void)updateSegments {
    for (NSUInteger i = 0; i < _segments.count; i++) {
        UIColor *c = [UIColor colorWithWhite:1 alpha:0.18];
        if (i < _results.count) c = _results[i].boolValue ? RTStyle.green : RTStyle.red;
        else if (i == _round.index) c = UIColor.whiteColor;
        _segments[i].backgroundColor = c;
    }
}

- (void)updateMinutes:(BOOL)animated {
    NSInteger target = [RTRound minutesForCorrect:_round.correctCount of:_round.count];
    [_tick invalidate];
    if (!animated || RTStyle.reduceMotion || target == _shownMinutes) {
        _shownMinutes = target;
        [self renderMinutes];
        return;
    }
    NSInteger from = _shownMinutes;
    CFTimeInterval start = CACurrentMediaTime();
    __weak typeof(self) weakSelf = self;
    _tick = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30 repeats:YES block:^(NSTimer *timer) {
        typeof(self) me = weakSelf;
        if (!me) { [timer invalidate]; return; }
        double t = MIN(1, (CACurrentMediaTime() - start) / 0.7);
        double eased = 1 - pow(1 - t, 3);
        me->_shownMinutes = from + (NSInteger)llround((target - from) * eased);
        [me renderMinutes];
        if (t >= 1) [timer invalidate];
    }];
}

- (void)renderMinutes {
    static NSNumberFormatter *f;
    if (!f) {
        f = [NSNumberFormatter new];
        f.numberStyle = NSNumberFormatterDecimalStyle;
        f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    }
    _minutes.attributedText = [RTStyle spaced:[f stringFromNumber:@(_shownMinutes)] font:[RTStyle stencil:30] color:RTStyle.yellow kern:1];
}

- (void)updateStreak {
    NSUInteger s = _round.streak;
    if (s < 3) {
        [UIView animateWithDuration:0.2 animations:^{ self->_streak.alpha = 0; }];
        return;
    }
    _streak.attributedText = [RTStyle spaced:[NSString stringWithFormat:@"%lu IN A ROW!", (unsigned long)s] font:[RTStyle stencil:18] color:RTStyle.ink kern:1.5];
    _streak.alpha = 1;
    [self.view setNeedsLayout];
    [self pop:_streak];
}

- (void)pop:(UIView *)v {
    if (RTStyle.reduceMotion) return;
    CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    a.values = @[@1, @1.08, @0.98, @1];
    a.duration = 0.35;
    [v.layer addAnimation:a forKey:@"pop"];
}

- (void)shake:(UIView *)v {
    if (RTStyle.reduceMotion) return;
    CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    a.values = @[@0, @-12, @10, @-7, @4, @0];
    a.duration = 0.4;
    [v.layer addAnimation:a forKey:@"shake"];
}

#pragma mark - Quit

- (void)confirmQuit {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Leave this round?" message:@"Your progress in this round will be lost."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Keep Playing" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Leave" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        RTShowScreen([RTTitleViewController new]);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize s = self.view.bounds.size;
    BOOL portrait = s.height > s.width;
    CGFloat side = portrait ? 40 : 56;
    _backdrop.frame = self.view.bounds;

    _close.frame = CGRectMake(side - 18, 16, 52, 52);
    CGSize prog = [_progress.attributedText size];
    _progress.frame = CGRectMake(side + 44, 28, prog.width + 4, 30);
    CGFloat logoH = 40, logoW = RTStyle.logo.size.height > 0 ? logoH * RTStyle.logo.size.width / RTStyle.logo.size.height : 0;
    _logo.frame = CGRectMake((s.width - logoW) / 2, 20, logoW, logoH);
    _logo.hidden = CGRectGetMaxX(_progress.frame) + 20 > _logo.frame.origin.x;
    _minutesCaption.frame = CGRectMake(s.width - side - 200, 16, 200, 16);
    _minutes.frame = CGRectMake(s.width - side - 200, 32, 200, 34);
    CGSize streak = [_streak.attributedText size];
    RTPlace(_streak, CGRectMake(s.width - side - 200 - streak.width - 40, 30, streak.width + 22, 30));
    _streak.transform = CGAffineTransformRotate(CGAffineTransformIdentity, 0.04);

    CGFloat segY = 80, gap = 4, n = _segments.count, segW = n ? (s.width - 2 * side - gap * (n - 1)) / n : 0;
    for (NSUInteger i = 0; i < _segments.count; i++) _segments[i].frame = CGRectMake(side + i * (segW + gap), segY, segW, 6);

    CGFloat cardH = portrait ? 420 : 300;
    CGRect cardFrame = CGRectMake(side, 104, s.width - 2 * side, cardH);
    if (CGAffineTransformIsIdentity(_card.transform)) _card.frame = cardFrame;
    [self layoutCard];

    CGFloat tileH = portrait ? 100 : 82, tileGap = 22;
    CGFloat tileW = (cardFrame.size.width - tileGap) / 2;
    CGFloat tilesY = CGRectGetMaxY(cardFrame) + 26;
    for (RTTileButton *t in _tiles) {
        NSUInteger i = t.tag;
        RTPlace(t, CGRectMake(side + (i % 2) * (tileW + tileGap), tilesY + (i / 2) * (tileH + tileGap), tileW, tileH));
        t.titleLabel.font = [RTStyle stencil:portrait ? 28 : 26];
    }
    CGFloat nextY = tilesY + 2 * tileH + tileGap + (portrait ? 34 : 22);
    RTPlace(_next, CGRectMake(s.width - side - 260, nextY, 260, MIN(64, s.height - nextY - 14)));
}

- (void)layoutCard {
    CGSize c = _card.bounds.size;
    CGFloat textX = 60, right = 36, top = 34;
    if (!_polaroid.hidden) {
        BOOL cast = [_round.question.image hasPrefix:@"cast/"];
        CGFloat h, w;
        if (cast) {
            h = c.height - 44;
            w = (h - 40) * 2 / 3 + 20;
        } else {
            w = MIN(380, c.width * 0.42);
            h = (w - 20) * 9 / 16 + 40;
        }
        RTPlace(_polaroid, CGRectMake(56, (c.height - h) / 2 + 4, w, h));
        textX = 56 + w + 34;
    }
    CGFloat textW = c.width - textX - right;

    CGFloat fh = _round.isAnswered ? [self heightOf:_fact.attributedText width:textW] : 0;
    CGFloat extra = _round.isAnswered ? 18 + 36 + 6 + fh : 0;
    CGFloat qh = 0;
    for (CGFloat size = 30; size >= 18; size -= 2) {
        _question.attributedText = [self questionText:_round.question.text size:size];
        qh = [self heightOf:_question.attributedText width:textW];
        if (qh + extra <= c.height - top - 20) break;
    }
    if (!_round.isAnswered) {
        _question.frame = CGRectMake(textX, MAX(top, (c.height - qh) / 2), textW, MIN(qh, c.height - top - 20));
        _feedback.frame = CGRectMake(textX, CGRectGetMaxY(_question.frame) + 12, textW, 36);
        _fact.frame = CGRectMake(textX, CGRectGetMaxY(_feedback.frame) + 4, textW, 0);
        return;
    }
    CGFloat block = qh + extra;
    CGFloat y = MAX(top - 6, (c.height - block) / 2);
    _question.frame = CGRectMake(textX, y, textW, qh);
    _feedback.frame = CGRectMake(textX, CGRectGetMaxY(_question.frame) + 18, textW, 36);
    _fact.frame = CGRectMake(textX, CGRectGetMaxY(_feedback.frame) + 6, textW, MIN(fh, c.height - CGRectGetMaxY(_feedback.frame) - 16));
}
@end
