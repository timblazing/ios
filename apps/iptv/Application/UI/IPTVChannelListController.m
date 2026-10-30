#import "IPTVChannelListController.h"
#import "IPTVPlayerController.h"
#import "../Guide/IPTVGuide.h"
#import "../Guide/IPTVGuideClient.h"

static UIColor *TVColor(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255)/255.0 green:((rgb >> 8) & 255)/255.0 blue:(rgb & 255)/255.0 alpha:1];
}
static UILabel *TVLabel(UIView *parent, NSString *text, CGFloat size, UIColor *color, CGRect frame) {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text; label.font = [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
    label.textColor = color; [parent addSubview:label]; return label;
}

@interface IPTVGuideCell : UICollectionViewCell
@property(nonatomic, strong) NSObject *represented;
@property(nonatomic, strong) NSMutableSet *logoKeys;
@end
@implementation IPTVGuideCell
@end

@interface IPTVChannelListController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@end

@implementation IPTVChannelListController {
    NSArray<UIButton *> *_tabs;
    NSInteger _selectedTab;
    UIVisualEffectView *_tabDock;
    UIView *_dockShadow;
    CAGradientLayer *_dockSheen;
    UICollectionView *_collection;
    UILabel *_message;
    IPTVGuide *_guide;
    NSArray<NSArray *> *_sections;
    NSArray<NSString *> *_headings;
    NSCache *_logos;
    NSMutableDictionary<NSString *, NSURLSessionDataTask *> *_logoTasks;
    NSMutableSet *_failedLogos;
    IPTVGuideClient *_client;
    NSTimer *_poll;
    BOOL _visible;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColor(0x0b0c0f);
    _client = [IPTVGuideClient new];
    _logos = [NSCache new]; _logos.totalCostLimit = 8 * 1024 * 1024;
    _logoTasks = [NSMutableDictionary new]; _failedLogos = [NSMutableSet new];
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumInteritemSpacing = 12; layout.minimumLineSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(0, 20, 16, 20);
    layout.headerReferenceSize = CGSizeMake(100, 38);
    _collection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collection.backgroundColor = self.view.backgroundColor;
    _collection.dataSource = self;
    _collection.delegate = self;
    [_collection registerClass:IPTVGuideCell.class forCellWithReuseIdentifier:@"card"];
    [_collection registerClass:UICollectionReusableView.class forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"heading"];
    [self.view addSubview:_collection];
    UIBlurEffect *blur = UIAccessibilityIsReduceTransparencyEnabled() ? nil : [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _tabDock = [[UIVisualEffectView alloc] initWithEffect:blur];
    _tabDock.backgroundColor = UIAccessibilityIsReduceTransparencyEnabled() ? TVColor(0x292a2c) : UIColor.clearColor;
    _tabDock.layer.cornerRadius = 30; _tabDock.clipsToBounds = YES;
    _tabDock.layer.borderWidth = 1/UIScreen.mainScreen.scale;
    _tabDock.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    _dockSheen = [CAGradientLayer layer];
    _dockSheen.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.14].CGColor,
                         (id)[UIColor colorWithWhite:1 alpha:0.02].CGColor,
                         (id)[UIColor colorWithWhite:1 alpha:0.06].CGColor];
    _dockSheen.locations = @[@0, @0.55, @1];
    _dockSheen.hidden = UIAccessibilityIsReduceTransparencyEnabled();
    [_tabDock.contentView.layer addSublayer:_dockSheen];
    _dockShadow = [UIView new];
    _dockShadow.layer.shadowColor = UIColor.blackColor.CGColor;
    _dockShadow.layer.shadowOpacity = 0.28;
    _dockShadow.layer.shadowRadius = 12;
    _dockShadow.layer.shadowOffset = CGSizeMake(0, 5);
    _dockShadow.userInteractionEnabled = NO;
    [self.view addSubview:_dockShadow];
    NSMutableArray *tabs = [NSMutableArray new];
    NSArray *titles = @[@"NFL", @"NBA", @"NCAAF"];
    for (NSUInteger index = 0; index < titles.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = index; button.layer.cornerRadius = 22;
        button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [button setTitle:titles[index] forState:UIControlStateNormal];
        [button setTitleColor:TVColor(0xa3a8b3) forState:UIControlStateNormal];
        [button setTitleColor:TVColor(0xf2f3f5) forState:UIControlStateSelected];
        button.accessibilityLabel = titles[index];
        [button addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_tabDock.contentView addSubview:button]; [tabs addObject:button];
    }
    _tabs = tabs;
    [self selectTab];
    [self.view addSubview:_tabDock];
    _message = TVLabel(self.view, @"TV isn’t configured yet.", 16, TVColor(0xa3a8b3), CGRectZero);
    _message.textAlignment = NSTextAlignmentCenter; _message.numberOfLines = 0;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationWillEnterForegroundNotification object:nil];
}
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    CGFloat dockWidth = MIN(350, w - 40);
    _tabDock.frame = CGRectMake((w-dockWidth)/2, h-84, dockWidth, 60);
    _dockShadow.frame = _tabDock.frame;
    _dockShadow.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_dockShadow.bounds cornerRadius:30].CGPath;
    _dockSheen.frame = _tabDock.bounds;
    CGFloat tabWidth = (dockWidth-16)/3;
    for (NSUInteger index = 0; index < _tabs.count; index++)
        _tabs[index].frame = CGRectMake(8+index*tabWidth, 8, tabWidth, 44);
    _collection.frame = self.view.bounds;
    _collection.contentInset = UIEdgeInsetsMake(20, 0, 104, 0);
    _collection.scrollIndicatorInsets = UIEdgeInsetsMake(20, 0, 104, 0);
    _message.frame = CGRectMake(30, h/2-40, w-60, 80);
    [_collection.collectionViewLayout invalidateLayout];
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    _collection.panGestureRecognizer.enabled = NO; _collection.panGestureRecognizer.enabled = YES;
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { [self->_collection reloadData]; }];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; self.navigationController.navigationBarHidden = YES; _visible = YES; [self foreground];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; _visible = NO; [self background]; }
- (void)background { [_poll invalidate]; _poll = nil; [_client cancel]; }
- (void)foreground {
    if (!_visible) return;
    [self reload]; [_poll invalidate];
    _poll = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(reload) userInfo:nil repeats:YES];
}
- (void)reload {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray *bases = @[[defaults stringForKey:@"gateway.baseURL"] ?: @"",
                       [defaults stringForKey:@"gateway.fallbackBaseURL"] ?: @""];
    __weak typeof(self) weakSelf = self;
    [_client reloadBaseURLs:bases completion:^(BOOL success) {
        typeof(self) self = weakSelf; if (!self) return;
        if (success) {
            self->_guide = self->_client.guide;
            [self selectTab];
        } else {
            self->_message.text = self->_guide ? @"Guide unavailable. Showing last update; retrying in 30 seconds." : @"Can’t load guide. Check the connection; retrying automatically.";
            self->_message.hidden = NO;
        }
    }];
}
- (IPTVLeague *)league {
    NSString *identifier = @[@"nfl", @"nba", @"ncaaf"][_selectedTab];
    for (IPTVLeague *league in _guide.leagues) if ([league.identifier isEqual:identifier]) return league;
    return nil;
}
- (void)tabTapped:(UIButton *)button { _selectedTab = button.tag; [self selectTab]; }
- (void)selectTab {
    IPTVLeague *league = [self league];
    for (NSUInteger index = 0; index < _tabs.count; index++) {
        UIButton *button = _tabs[index];
        button.selected = index == (NSUInteger)_selectedTab;
        button.backgroundColor = button.selected ? [UIColor colorWithWhite:1 alpha:0.14] : UIColor.clearColor;
        button.layer.borderWidth = button.selected ? 1/UIScreen.mainScreen.scale : 0;
        button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
        button.accessibilityTraits = UIAccessibilityTraitButton | (button.selected ? UIAccessibilityTraitSelected : 0);
    }
    NSMutableArray *sections = [NSMutableArray new], *headings = [NSMutableArray new];
    NSDateFormatter *day = [NSDateFormatter new]; day.dateFormat = @"EEEE, MMM d";
    for (NSString *state in @[@"in", @"pre", @"post"]) {
        for (IPTVGame *game in league.games) {
            if (![game.state isEqual:state]) continue;
            NSString *heading = [state isEqual:@"in"] ? @"● LIVE" : [state isEqual:@"post"] ? @"FINAL" : ([NSCalendar.currentCalendar isDateInToday:game.start] ? @"TONIGHT" : [[day stringFromDate:game.start] uppercaseString]);
            if (![headings.lastObject isEqual:heading]) { [headings addObject:heading]; [sections addObject:[NSMutableArray new]]; }
            [sections.lastObject addObject:game];
        }
    }
    if (league.channels.count) { [sections addObject:league.channels]; [headings addObject:@"CHANNELS"]; }
    _sections = sections; _headings = headings; [_collection reloadData];
    _message.hidden = sections.count > 0;
    _message.text = _guide ? @"No games or channels in this league." : @"TV isn’t configured yet.";
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView { return _sections.count; }
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return _sections[section].count; }
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)path {
    CGFloat w = collectionView.bounds.size.width; NSInteger columns = self.view.bounds.size.width > self.view.bounds.size.height ? 3 : 2;
    return CGSizeMake(floor((w-40-(columns-1)*12)/columns), [_sections[path.section][path.item] isKindOfClass:IPTVGame.class] ? 138 : 86);
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)path {
    UICollectionReusableView *view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"heading" forIndexPath:path];
    for (UIView *child in view.subviews) [child removeFromSuperview];
    TVLabel(view, _headings[path.section], 13, [_headings[path.section] isEqual:@"● LIVE"] ? TVColor(0xff3b30) : TVColor(0xa3a8b3), CGRectMake(20, 0, collectionView.bounds.size.width-40, 38));
    return view;
}
- (void)logo:(NSString *)path inView:(UIView *)parent frame:(CGRect)frame fallback:(NSString *)fallback color:(NSString *)hex {
    UILabel *badge = TVLabel(parent, fallback, 11, UIColor.whiteColor, frame);
    unsigned rgb = 0x333333; [[NSScanner scannerWithString:hex ?: @""] scanHexInt:&rgb];
    badge.backgroundColor = TVColor(rgb); badge.textAlignment = NSTextAlignmentCenter; badge.layer.cornerRadius = frame.size.height/2; badge.clipsToBounds = YES;
    if (![path hasPrefix:@"/logo?"]) return;
    NSString *base = _client.baseURL;
    NSURLComponents *components = [NSURLComponents componentsWithString:[base stringByAppendingString:path]];
    NSMutableArray *query = [NSMutableArray new]; for (NSURLQueryItem *item in components.queryItems) if (![item.name isEqual:@"s"]) [query addObject:item];
    [query addObject:[NSURLQueryItem queryItemWithName:@"s" value:@"96"]]; components.queryItems = query;
    NSString *key = components.URL.absoluteString;
    IPTVGuideCell *cell = (IPTVGuideCell *)parent.superview;
    [cell.logoKeys addObject:key];
    UIImage *cached = [_logos objectForKey:key];
    if (cached) { badge.hidden = YES; UIImageView *image = [[UIImageView alloc] initWithImage:cached]; image.frame = frame; image.contentMode = UIViewContentModeScaleAspectFit; [parent addSubview:image]; return; }
    if (_logoTasks[key] || [_failedLogos containsObject:key]) return;
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:components.URL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *source = data.length <= 1024*1024 ? [UIImage imageWithData:data] : nil;
        UIImage *decoded = nil;
        if (source && source.size.width <= 256 && source.size.height <= 256) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(48, 48), NO, 2);
            CGFloat scale = MIN(48/source.size.width, 48/source.size.height);
            CGSize size = CGSizeMake(source.size.width*scale, source.size.height*scale);
            [source drawInRect:CGRectMake((48-size.width)/2, (48-size.height)/2, size.width, size.height)];
            decoded = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf; if (!self) return;
            [self->_logoTasks removeObjectForKey:key];
            if (!decoded) [self->_failedLogos addObject:key];
            if (decoded) { [self->_logos setObject:decoded forKey:key cost:96*96*4];
                NSMutableArray *affected = [NSMutableArray new];
                for (NSIndexPath *index in self->_collection.indexPathsForVisibleItems) {
                    IPTVGuideCell *visible = (IPTVGuideCell *)[self->_collection cellForItemAtIndexPath:index];
                    if ([visible.logoKeys containsObject:key]) [affected addObject:index];
                }
                if (affected.count) [self->_collection reloadItemsAtIndexPaths:affected];
            }
        });
    }]; _logoTasks[key] = task; [task resume];
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)path {
    IPTVGuideCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"card" forIndexPath:path];
    for (UIView *child in cell.contentView.subviews) [child removeFromSuperview];
    cell.contentView.backgroundColor = TVColor(0x15171c); cell.contentView.layer.cornerRadius = 14;
    NSObject *object = _sections[path.section][path.item]; cell.represented = object; cell.isAccessibilityElement = YES; cell.accessibilityTraits = UIAccessibilityTraitButton; cell.logoKeys = [NSMutableSet new];
    CGFloat w = cell.bounds.size.width;
    if ([object isKindOfClass:IPTVGame.class]) {
        IPTVGame *game = (IPTVGame *)object;
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@ at %@, %@, %@, %@ to %@", game.away.name, game.home.name, game.detail, game.tv, game.away.score, game.home.score];
        if ([game.state isEqual:@"pre"]) cell.accessibilityLabel = [NSString stringWithFormat:@"%@ at %@, %@, %@", game.away.name, game.home.name, game.detail, game.tv];
        NSDateFormatter *clock = [NSDateFormatter new]; clock.dateFormat = @"h:mm a";
        NSString *status = [game.state isEqual:@"pre"] ? [clock stringFromDate:game.start] : game.detail;
        TVLabel(cell.contentView, status, 13, [game.state isEqual:@"in"] ? TVColor(0xff3b30) : TVColor(0xf2f3f5), CGRectMake(14, 10, w*.45, 20));
        UILabel *network = TVLabel(cell.contentView, game.tv, 11, TVColor(0xa3a8b3), CGRectMake(w*.45, 10, w*.55-14, 20)); network.textAlignment = NSTextAlignmentCenter;
        CGSize chip = [network sizeThatFits:CGSizeMake(w*.55-14, 20)];
        network.frame = CGRectMake(w-MIN(w*.55-14, chip.width+12)-14, 12, MIN(w*.55-14, chip.width+12), 17);
        network.backgroundColor = TVColor(0x1f2229); network.layer.cornerRadius = 4; network.clipsToBounds = YES;
        NSArray *teams = @[game.away, game.home];
        for (NSUInteger i=0; i<2; i++) {
            IPTVTeam *team = teams[i]; CGFloat y = 36+i*46;
            [self logo:team.logo inView:cell.contentView frame:CGRectMake(14, y+5, 36, 36) fallback:team.abbr color:team.color];
            BOOL pre = [game.state isEqual:@"pre"];
            UILabel *name = TVLabel(cell.contentView, team.nick.length ? team.nick : team.name, 18, TVColor(0xf2f3f5), CGRectMake(62, y, w-(pre ? 76 : 130), 46));
            if (pre && team.record.length) {
                NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@  %@", name.text, team.record]];
                [text addAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13], NSForegroundColorAttributeName:TVColor(0x6b7180)} range:NSMakeRange(text.length-team.record.length, team.record.length)];
                name.attributedText = text;
            }
            UILabel *score = TVLabel(cell.contentView, pre ? @"" : team.score, pre ? 13 : 24, TVColor(pre ? 0x6b7180 : 0xf2f3f5), CGRectMake(w-66, y, 52, 46)); score.textAlignment = NSTextAlignmentRight;
        }
    } else {
        IPTVGuideChannel *channel = (IPTVGuideChannel *)object;
        cell.accessibilityLabel = channel.name;
        [self logo:channel.logo inView:cell.contentView frame:CGRectMake(14, 20, 56, 44) fallback:[channel.name substringToIndex:MIN(2, channel.name.length)] color:@"1f2229"];
        NSDictionary *now = nil, *next = nil; NSDate *date = [NSDate date];
        for (NSDictionary *entry in channel.epg) {
            NSDate *start = [IPTVGuide dateFromString:entry[@"start"]], *end = [IPTVGuide dateFromString:entry[@"end"]];
            if (start && end && [start compare:date] != NSOrderedDescending && [end compare:date] == NSOrderedDescending) now = entry;
            else if (start && [start compare:date] == NSOrderedDescending && !next) next = entry;
        }
        TVLabel(cell.contentView, now[@"title"] ?: channel.name, 15, TVColor(0xf2f3f5), CGRectMake(84, 14, w-98, 22));
        TVLabel(cell.contentView, [NSString stringWithFormat:@"%@ · %@", channel.name, next ? [@"Next: " stringByAppendingString:next[@"title"]] : @"No guide data"], 12, TVColor(0x6b7180), CGRectMake(84, 38, w-98, 20));
        if (now) {
            UIProgressView *progress = [[UIProgressView alloc] initWithFrame:CGRectMake(84, 68, w-98, 3)];
            NSDate *start = [IPTVGuide dateFromString:now[@"start"]], *end = [IPTVGuide dateFromString:now[@"end"]];
            progress.progress = MIN(1, MAX(0, [date timeIntervalSinceDate:start]/[end timeIntervalSinceDate:start]));
            progress.progressTintColor = TVColor(0xa3a8b3); progress.trackTintColor = TVColor(0x1f2229); [cell.contentView addSubview:progress];
        }
    }
    return cell;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)path {
    NSObject *object = _sections[path.section][path.item];
    if ([object isKindOfClass:IPTVGame.class]) {
        IPTVGame *game = (IPTVGame *)object;
        if ([game.state isEqual:@"pre"]) {
            NSDateFormatter *format = [NSDateFormatter new]; format.dateStyle = NSDateFormatterFullStyle; format.timeStyle = NSDateFormatterShortStyle;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Game hasn't started" message:[format stringFromDate:game.start] preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:alert animated:YES completion:nil]; return;
        }
        NSArray *games = [self league].games;
        [self presentViewController:[[IPTVPlayerController alloc] initWithGames:games index:[games indexOfObject:game]] animated:YES completion:nil];
    } else [self presentViewController:[[IPTVPlayerController alloc] initWithChannel:(IPTVGuideChannel *)object] animated:YES completion:nil];
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self]; [_poll invalidate]; [_client cancel];
    for (NSURLSessionDataTask *task in _logoTasks.allValues) [task cancel];
}
@end
