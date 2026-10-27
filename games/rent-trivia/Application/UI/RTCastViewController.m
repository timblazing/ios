#import "RTCastViewController.h"
#import "RTStyle.h"
#import "RTTitleViewController.h"

@implementation RTCastViewController {
    RTBackdropView *_backdrop;
    UIImageView *_logo;
    UILabel *_heading;
    RTTileButton *_back;
    NSMutableArray<UIView *> *_cards;
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    _backdrop = [RTBackdropView new];
    _backdrop.dim = 0.8;
    [_backdrop showImageNamed:@"collage" animated:NO];
    [self.view addSubview:_backdrop];

    _logo = [[UIImageView alloc] initWithImage:RTStyle.logo];
    _logo.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_logo];
    _heading = [UILabel new];
    _heading.attributedText = [RTStyle spaced:@"THE CAST" font:[RTStyle stencil:24] color:UIColor.whiteColor kern:6];
    _heading.textAlignment = NSTextAlignmentCenter;
    _heading.backgroundColor = RTStyle.red;
    [self.view addSubview:_heading];

    _back = [RTTileButton tileWithTitle:@"‹  MENU" color:RTStyle.blue];
    _back.titleLabel.font = [RTStyle stencil:22];
    _back.tilt = -0.02;
    [_back addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_back];

    NSArray *cast = @[@[@"MARK", @"Anthony Rapp", @"mark", @"The filmmaker"], @[@"ROGER", @"Adam Pascal", @"roger", @"The songwriter"],
                      @[@"MIMI", @"Rosario Dawson", @"mimi", @"The dancer"], @[@"COLLINS", @"Jesse L. Martin", @"collins", @"The professor"],
                      @[@"ANGEL", @"Wilson Jermaine Heredia", @"angel", @"The drummer"], @[@"MAUREEN", @"Idina Menzel", @"maureen", @"The performer"],
                      @[@"JOANNE", @"Tracie Thoms", @"joanne", @"The lawyer"], @[@"BENNY", @"Taye Diggs", @"benny", @"The landlord"]];
    _cards = [NSMutableArray array];
    for (NSUInteger i = 0; i < cast.count; i++) {
        NSArray *c = cast[i];
        UIView *card = [UIView new];
        card.backgroundColor = UIColor.whiteColor;
        card.layer.shadowColor = UIColor.blackColor.CGColor;
        card.layer.shadowOpacity = 0.6;
        card.layer.shadowRadius = 8;
        card.layer.shadowOffset = CGSizeMake(0, 5);
        card.isAccessibilityElement = YES;
        card.accessibilityLabel = [NSString stringWithFormat:@"%@, played by %@", [c[0] capitalizedString], c[1]];

        UIImageView *photo = [UIImageView new];
        photo.contentMode = UIViewContentModeScaleAspectFill;
        photo.clipsToBounds = YES;
        photo.tag = 1;
        photo.backgroundColor = UIColor.darkGrayColor;
        [RTStyle loadImageNamed:[@"cast/" stringByAppendingString:c[2]] completion:^(UIImage *image) { photo.image = image; }];
        [card addSubview:photo];

        UIView *band = [UIView new];
        band.backgroundColor = [RTStyle bandColor:i];
        band.tag = 2;
        [card addSubview:band];
        UILabel *name = [UILabel new];
        name.attributedText = [RTStyle spaced:c[0] font:[RTStyle stencil:28] color:UIColor.whiteColor kern:3];
        name.textAlignment = NSTextAlignmentCenter;
        name.adjustsFontSizeToFitWidth = YES;
        name.minimumScaleFactor = 0.6;
        name.tag = 3;
        [card addSubview:name];
        UILabel *actor = [UILabel new];
        actor.attributedText = [RTStyle spaced:c[1] font:[RTStyle typeBold:14] color:RTStyle.ink kern:0.2];
        actor.textAlignment = NSTextAlignmentCenter;
        actor.adjustsFontSizeToFitWidth = YES;
        actor.minimumScaleFactor = 0.5;
        actor.tag = 4;
        [card addSubview:actor];
        UILabel *role = [UILabel new];
        role.attributedText = [RTStyle spaced:c[3] font:[RTStyle type:13] color:[RTStyle.ink colorWithAlphaComponent:0.6] kern:0.2];
        role.textAlignment = NSTextAlignmentCenter;
        role.tag = 5;
        [card addSubview:role];

        card.transform = CGAffineTransformMakeRotation(((NSInteger)(i * 7 % 5) - 2) * 0.012);
        [_cards addObject:card];
        [self.view addSubview:card];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize s = self.view.bounds.size;
    BOOL portrait = s.height > s.width;
    _backdrop.frame = self.view.bounds;

    CGFloat logoH = 64, logoW = RTStyle.logo.size.height > 0 ? logoH * RTStyle.logo.size.width / RTStyle.logo.size.height : 0;
    _logo.frame = CGRectMake((s.width - logoW) / 2, 28, logoW, logoH);
    CGSize h = [_heading.attributedText size];
    RTPlace(_heading, CGRectMake((s.width - h.width - 30) / 2, 102, h.width + 30, 34));
    _heading.transform = CGAffineTransformMakeRotation(0.02);
    RTPlace(_back, CGRectMake(30, 30, 150, 56));

    NSUInteger cols = 4, rows = 2;
    CGFloat gap = portrait ? 22 : 28, top = 160, bottom = portrait ? 60 : 28;
    CGFloat cardW = (s.width - 2 * (portrait ? 34 : 70) - gap * (cols - 1)) / cols;
    CGFloat maxH = (s.height - top - bottom - gap * (rows - 1)) / rows;
    CGFloat photoH = MIN(cardW * 1.5, maxH - 64);
    CGFloat photoW = MIN(cardW, photoH / 1.5 + 0);
    cardW = photoW;
    CGFloat cardH = photoH + 64;
    CGFloat totalW = cols * cardW + (cols - 1) * gap, x0 = (s.width - totalW) / 2;
    CGFloat y0 = top + (s.height - top - bottom - rows * cardH - (rows - 1) * gap) / 2;
    for (NSUInteger i = 0; i < _cards.count; i++) {
        UIView *card = _cards[i];
        RTPlace(card, CGRectMake(x0 + (i % cols) * (cardW + gap), y0 + (i / cols) * (cardH + gap), cardW, cardH));
        card.layer.shadowPath = [UIBezierPath bezierPathWithRect:card.bounds].CGPath;
        CGFloat m = 7, pw = cardW - 2 * m;
        [card viewWithTag:1].frame = CGRectMake(m, m, pw, photoH - 2 * m);
        [card viewWithTag:2].frame = CGRectMake(m, photoH - m - 36, pw, 36);
        [card viewWithTag:3].frame = CGRectMake(m + 6, photoH - m - 36, pw - 12, 36);
        [card viewWithTag:4].frame = CGRectMake(m, photoH + 4, pw, 22);
        [card viewWithTag:5].frame = CGRectMake(m, photoH + 28, pw, 18);
    }
}

- (void)goBack { RTShowScreen([RTTitleViewController new]); }
@end
