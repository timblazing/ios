#import "Panels.h"
#import <CoreText/SFNTLayoutTypes.h>
#import "../Game/PuzzleCalendar.h"
#import "Icons.h"
#import "Theme.h"
#import "TileView.h"

NSString *PuzzleNumber(NSInteger day) {
    return [NSNumberFormatter localizedStringFromNumber:@(day) numberStyle:NSNumberFormatterDecimalStyle];
}

static NSAttributedString *Rich(NSString *text, NSArray<NSString *> *bold, CGFloat size) {
    NSMutableAttributedString *s =
        [[NSMutableAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName : [Theme fontOfSize:size]}];
    for (NSString *word in bold)
        [s addAttribute:NSFontAttributeName value:[Theme boldFontOfSize:size] range:[text rangeOfString:word]];
    return s;
}

#pragma mark - Help

@implementation HelpPanel {
    NSMutableArray<TileView *> *_tiles;
}
- (instancetype)init {
    if (!(self = [super initWithStyle:PanelStylePage title:@"How to play"]))
        return nil;
    _tiles = [NSMutableArray array];
    [self addText:Rich(@"Guess the WORDLE in six tries.", @[ @"WORDLE" ], 16) spacing:0];
    [self addText:Rich(@"Each guess must be a valid five-letter word. Hit the enter button to submit.", @[], 16)
          spacing:14];
    [self addText:Rich(@"After each guess, the color of the tiles will change to show how close your guess was to "
                       @"the word.",
                       @[], 16)
          spacing:14];
    [self addRow:[self divider] spacing:16];
    [self addText:Rich(@"Examples", @[ @"Examples" ], 16) spacing:16];
    [self example:@"WEARY" index:0 state:LetterStateCorrect];
    [self addText:Rich(@"The letter W is in the word and in the correct spot.", @[ @"W" ], 16) spacing:10];
    [self example:@"PILLS" index:1 state:LetterStatePresent];
    [self addText:Rich(@"The letter I is in the word but in the wrong spot.", @[ @"I" ], 16) spacing:10];
    [self example:@"VAGUE" index:3 state:LetterStateAbsent];
    [self addText:Rich(@"The letter U is not in the word in any spot.", @[ @"U" ], 16) spacing:10];
    [self addRow:[self divider] spacing:16];
    [self addText:Rich(@"A new WORDLE will be available each day!", @[ @"A new WORDLE will be available each day!" ], 16)
          spacing:16];
    return self;
}
- (void)addText:(NSAttributedString *)text spacing:(CGFloat)spacing {
    UILabel *label = [self labelWithText:nil font:nil];
    label.attributedText = text;
    [self addRow:label spacing:spacing];
}
- (void)example:(NSString *)word index:(NSUInteger)index state:(LetterState)state {
    CGFloat size = 44, gap = 4;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5 * size + 4 * gap, size)];
    for (NSUInteger i = 0; i < 5; i++) {
        TileView *tile = [[TileView alloc] initWithFrame:CGRectMake(i * (size + gap), 0, size, size)];
        tile.letter = [word substringWithRange:NSMakeRange(i, 1)];
        tile.state = i == index ? state : LetterStateNone;
        [row addSubview:tile];
        [_tiles addObject:tile];
    }
    row.isAccessibilityElement = YES;
    row.accessibilityLabel = word;
    [self addRow:row spacing:20];
}
- (void)applyTheme {
    [super applyTheme];
    for (TileView *tile in _tiles)
        [tile applyTheme];
}
@end

#pragma mark - Settings

@interface SettingRow : UIView
@property(nonatomic, strong) UILabel *title, *detail;
@property(nonatomic, strong) UISwitch *toggle;
@property(nonatomic, copy) NSString *key;
@end
@implementation SettingRow
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.bounds.size, sw = self.toggle.bounds.size;
    CGFloat textWidth = size.width - sw.width - 16;
    CGFloat th = ceil([self.title sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)].height);
    CGFloat dh = self.detail.text ? ceil([self.detail sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)].height) : 0;
    CGFloat y = round((size.height - th - dh - (dh ? 2 : 0)) / 2);
    self.title.frame = CGRectMake(0, y, textWidth, th);
    self.detail.frame = CGRectMake(0, y + th + 2, textWidth, dh);
    self.toggle.frame = CGRectMake(size.width - sw.width, round((size.height - sw.height) / 2), sw.width, sw.height);
}
@end

@implementation SettingsPanel {
    NSMutableArray<SettingRow *> *_settings;
    UILabel *_footer;
}
- (instancetype)initWithValues:(NSDictionary<NSString *, NSNumber *> *)values {
    if (!(self = [super initWithStyle:PanelStylePage title:@"Settings"]))
        return nil;
    _settings = [NSMutableArray array];
    NSArray *rows = @[
        @[ @"hardMode", @"Hard Mode", @"Any revealed hints must be used in subsequent guesses" ],
        @[ @"darkTheme", @"Dark Theme", @"" ], @[ @"highContrast", @"High Contrast Mode", @"For improved color vision" ]
    ];
    for (NSArray *spec in rows) {
        SettingRow *row = [[SettingRow alloc] initWithFrame:CGRectMake(0, 0, 0, 72)];
        row.key = spec[0];
        row.title = [self labelWithText:spec[1] font:[Theme fontOfSize:18]];
        row.detail = [self labelWithText:[spec[2] length] ? spec[2] : nil font:[Theme fontOfSize:12]];
        row.toggle = [UISwitch new];
        row.toggle.on = [values[spec[0]] boolValue];
        row.toggle.accessibilityLabel = spec[1];
        row.toggle.layer.cornerRadius = 16;
        [row.toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:row.title];
        [row addSubview:row.detail];
        [row addSubview:row.toggle];
        [_settings addObject:row];
        [self addRow:row spacing:0];
        [self addRow:[self divider] spacing:0];
    }
    _footer = [self labelWithText:@"Puzzles come from the New York Times Wordle archive. Guesses are checked against "
                                  @"the iPad's built-in dictionary."
                             font:[Theme fontOfSize:12]];
    _footer.tag = 1;
    [self addRow:_footer spacing:16];
    [self applyTheme];
    return self;
}
- (void)toggled:(UISwitch *)toggle {
    for (SettingRow *row in _settings)
        if (row.toggle == toggle && self.onChange && !self.onChange(row.key, toggle.on))
            [toggle setOn:!toggle.on animated:YES];
}
- (void)applyTheme {
    [super applyTheme];
    for (SettingRow *row in _settings) {
        row.title.textColor = [Theme text];
        row.detail.textColor = [Theme secondaryText];
        row.toggle.onTintColor = [Theme colorForState:LetterStateCorrect];
        row.toggle.tintColor = [Theme filledBorder];
        row.toggle.backgroundColor = [Theme filledBorder];
    }
    _footer.textColor = [Theme secondaryText];
}
@end

#pragma mark - Statistics

@implementation StatsPanel {
    WordleStats *_stats;
    NSInteger _highlight;
    BOOL _gameOver, _practice;
    NSArray<UILabel *> *_numbers, *_captions;
    UILabel *_distributionTitle, *_noData, *_nextTitle, *_countdown;
    NSArray<UILabel *> *_rowLabels, *_barLabels;
    NSArray<UIView *> *_bars;
    UIView *_footerLine;
    UIButton *_share, *_newPractice;
    NSTimer *_timer;
}
- (instancetype)initWithStats:(WordleStats *)stats
                        today:(NSInteger)today
                 highlightRow:(NSInteger)highlightRow
                     gameOver:(BOOL)gameOver
                     practice:(BOOL)practice {
    if (!(self = [super initWithStyle:PanelStyleModal title:@"Statistics"]))
        return nil;
    _stats = stats;
    _highlight = highlightRow;
    _gameOver = gameOver;
    _practice = practice;
    UIView *content = self.contentView;
    NSArray *values = @[ @(stats.played), @([stats winPercent]), @([stats currentStreakOnDay:today]), @(stats.maxStreak) ];
    NSMutableArray *numbers = [NSMutableArray array], *captions = [NSMutableArray array];
    for (NSUInteger i = 0; i < 4; i++) {
        UILabel *number = [self labelWithText:[values[i] stringValue] font:[Theme fontOfSize:36]];
        number.textAlignment = NSTextAlignmentCenter;
        UILabel *caption = [self labelWithText:@[ @"Played", @"Win %", @"Current\nStreak", @"Max\nStreak" ][i]
                                          font:[Theme fontOfSize:12]];
        caption.textAlignment = NSTextAlignmentCenter;
        [content addSubview:number];
        [content addSubview:caption];
        [numbers addObject:number];
        [captions addObject:caption];
    }
    _numbers = numbers;
    _captions = captions;
    _distributionTitle = [self labelWithText:@"GUESS DISTRIBUTION" font:[Theme boldFontOfSize:16]];
    _distributionTitle.textAlignment = NSTextAlignmentCenter;
    _distributionTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    [content addSubview:_distributionTitle];
    if (stats.played == 0) {
        _noData = [self labelWithText:@"No Data" font:[Theme fontOfSize:14]];
        _noData.textAlignment = NSTextAlignmentCenter;
        [content addSubview:_noData];
    } else {
        NSMutableArray *rowLabels = [NSMutableArray array], *bars = [NSMutableArray array],
                       *barLabels = [NSMutableArray array];
        for (NSUInteger i = 0; i < 6; i++) {
            UILabel *n = [self labelWithText:@(i + 1).stringValue font:[Theme fontOfSize:14]];
            UIView *bar = [UIView new];
            UILabel *count = [self labelWithText:[stats.distribution[i] stringValue] font:[Theme boldFontOfSize:14]];
            count.textAlignment = NSTextAlignmentRight;
            count.textColor = [UIColor whiteColor];
            [bar addSubview:count];
            [content addSubview:n];
            [content addSubview:bar];
            [rowLabels addObject:n];
            [bars addObject:bar];
            [barLabels addObject:count];
        }
        _rowLabels = rowLabels;
        _bars = bars;
        _barLabels = barLabels;
    }
    if (gameOver) {
        _nextTitle = [self labelWithText:@"NEXT WORDLE" font:[Theme boldFontOfSize:16]];
        _nextTitle.textAlignment = NSTextAlignmentCenter;
        _countdown = [self labelWithText:nil font:[Theme fontOfSize:36]];
        _countdown.textAlignment = NSTextAlignmentCenter;
        {
            UIFontDescriptor *mono = [_countdown.font.fontDescriptor fontDescriptorByAddingAttributes:@{
                UIFontDescriptorFeatureSettingsAttribute : @[ @{
                    UIFontFeatureTypeIdentifierKey : @(kNumberSpacingType),
                    UIFontFeatureSelectorIdentifierKey : @(kMonospacedNumbersSelector)
                } ]
            }];
            _countdown.font = [UIFont fontWithDescriptor:mono size:36];
        }
        _footerLine = [UIView new];
        _share = [UIButton buttonWithType:UIButtonTypeCustom];
        [_share setTitle:@"SHARE " forState:UIControlStateNormal];
        [_share setImage:Icon(@"share") forState:UIControlStateNormal];
        _share.titleLabel.font = [Theme boldFontOfSize:20];
        _share.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft; // icon after the title
        _share.tintColor = [UIColor whiteColor];
        _share.layer.cornerRadius = 4;
        _share.accessibilityLabel = @"Share";
        [_share addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *v in @[ _nextTitle, _countdown, _footerLine, _share ])
            [content addSubview:v];
        [self tick];
        __weak StatsPanel *weakSelf = self;
        _timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                 repeats:YES
                                                   block:^(NSTimer *timer) {
                                                       [weakSelf tick];
                                                   }];
    }
    if (practice && gameOver) {
        _newPractice = [UIButton buttonWithType:UIButtonTypeCustom];
        [_newPractice setTitle:@"NEW PRACTICE PUZZLE" forState:UIControlStateNormal];
        _newPractice.titleLabel.font = [Theme boldFontOfSize:16];
        _newPractice.layer.cornerRadius = 4;
        [_newPractice addTarget:self action:@selector(newPracticeTapped) forControlEvents:UIControlEventTouchUpInside];
        [content addSubview:_newPractice];
    }
    [self applyTheme];
    return self;
}
- (void)tick {
    NSInteger s = (NSInteger)[PuzzleCalendar secondsUntilNextDayFrom:[NSDate date]];
    _countdown.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)(s / 3600), (long)(s / 60 % 60), (long)(s % 60)];
}
- (void)shareTapped {
    if (self.onShare)
        self.onShare();
}
- (void)newPracticeTapped {
    if (self.onNewPractice)
        self.onNewPractice();
}
- (void)dismiss {
    [_timer invalidate];
    [super dismiss];
}
- (CGFloat)layoutContentForWidth:(CGFloat)width {
    CGFloat column = MIN(80, width / 4), x0 = round((width - 4 * column) / 2), y = 0;
    for (NSUInteger i = 0; i < 4; i++) {
        _numbers[i].frame = CGRectMake(x0 + i * column, y, column, 42);
        _captions[i].frame = CGRectMake(x0 + i * column, y + 42, column, 30);
    }
    y += 72 + 16;
    _distributionTitle.frame = CGRectMake(0, y, width, 20);
    y += 20 + 10;
    if (_noData) {
        _noData.frame = CGRectMake(0, y, width, 20);
        y += 20;
    } else {
        NSInteger most = 1;
        for (NSNumber *n in _stats.distribution)
            most = MAX(most, n.integerValue);
        CGFloat rowWidth = round(width * 0.8), rx = round((width - rowWidth) / 2), barMax = rowWidth - 16;
        for (NSUInteger i = 0; i < 6; i++) {
            _rowLabels[i].frame = CGRectMake(rx, y, 12, 20);
            CGFloat fraction = MAX(0.07, (CGFloat)[_stats.distribution[i] integerValue] / most);
            _bars[i].frame = CGRectMake(rx + 16, y, round(barMax * fraction), 20);
            _barLabels[i].frame = CGRectMake(0, 0, _bars[i].bounds.size.width - 8, 20);
            y += 24;
        }
        y -= 4;
    }
    if (_share) {
        y += 24;
        CGFloat half = width / 2;
        _nextTitle.frame = CGRectMake(0, y, half, 20);
        _countdown.frame = CGRectMake(0, y + 20, half, 44);
        _footerLine.frame = CGRectMake(half, y, 1, 64);
        CGFloat bw = round(half * 0.8);
        _share.frame = CGRectMake(half + round((half - bw) / 2), y + 6, bw, 52);
        y += 64;
    }
    if (_newPractice) {
        y += 20;
        _newPractice.frame = CGRectMake(0, y, width, 48);
        y += 48;
    }
    return y;
}
- (void)applyTheme {
    [super applyTheme];
    for (UILabel *l in [_numbers arrayByAddingObjectsFromArray:_captions])
        l.textColor = [Theme text];
    for (UILabel *l in _rowLabels)
        l.textColor = [Theme text];
    _distributionTitle.textColor = _noData.textColor = _nextTitle.textColor = _countdown.textColor = [Theme text];
    for (NSUInteger i = 0; i < _bars.count; i++)
        _bars[i].backgroundColor = [Theme colorForState:(NSInteger)i == _highlight ? LetterStateCorrect : LetterStateAbsent];
    _footerLine.backgroundColor = [Theme text];
    _share.backgroundColor = [Theme colorForState:LetterStateCorrect];
    _newPractice.backgroundColor = [Theme key];
    [_newPractice setTitleColor:[Theme keyText] forState:UIControlStateNormal];
}
@end

#pragma mark - Menu

@interface MenuItem : UIControl
@property(nonatomic, strong) UILabel *title, *detail;
@property(nonatomic, strong) UIView *accent;
@end
@implementation MenuItem
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    self.accent.frame = CGRectMake(0, 10, 4, self.bounds.size.height - 20);
    self.title.frame = CGRectMake(20, 12, w - 40, 22);
    self.detail.frame = CGRectMake(20, 34, w - 40, 18);
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.6 : 1;
}
@end

@implementation MenuPanel {
    NSMutableArray<MenuItem *> *_items;
    BOOL _practice;
}
- (instancetype)initWithToday:(NSInteger)today practice:(BOOL)practice practiceDay:(NSInteger)practiceDay {
    if (!(self = [super initWithStyle:PanelStyleDrawer title:@"Wordle"]))
        return nil;
    _items = [NSMutableArray array];
    _practice = practice;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"EEEEMMMMd" options:0 locale:[NSLocale currentLocale]];
    NSString *date = [formatter stringFromDate:[NSDate date]];
    [self item:@"Today's Wordle"
        detail:[NSString stringWithFormat:@"No. %@ · %@", PuzzleNumber(today), date]
       current:!practice
        action:@selector(daily)];
    [self item:@"Practice"
        detail:practice || practiceDay < 0 ? @"A random puzzle from the archive"
                                           : [NSString stringWithFormat:@"Resume No. %@", PuzzleNumber(practiceDay)]
       current:practice
        action:@selector(practice)];
    if (practice)
        [self item:@"New practice puzzle" detail:@"Skip to another random puzzle" current:NO action:@selector(newPractice)];
    [self applyTheme];
    return self;
}
- (void)item:(NSString *)title detail:(NSString *)detail current:(BOOL)current action:(SEL)action {
    MenuItem *item = [[MenuItem alloc] initWithFrame:CGRectMake(0, 0, 0, 64)];
    item.title = [self labelWithText:title font:[Theme boldFontOfSize:17]];
    item.detail = [self labelWithText:detail font:[Theme fontOfSize:13]];
    item.accent = [UIView new];
    item.accent.hidden = !current;
    item.isAccessibilityElement = YES;
    item.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", title, detail];
    item.accessibilityTraits = UIAccessibilityTraitButton | (current ? UIAccessibilityTraitSelected : 0);
    for (UIView *v in @[ item.accent, item.title, item.detail ])
        [item addSubview:v];
    [item addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_items addObject:item];
    [self addRow:item spacing:0];
    [self addRow:[self divider] spacing:0];
}
- (void)daily {
    if (self.onDaily)
        self.onDaily();
}
- (void)practice {
    if (self.onPractice)
        self.onPractice();
}
- (void)newPractice {
    if (self.onNewPractice)
        self.onNewPractice();
}
- (void)applyTheme {
    [super applyTheme];
    for (MenuItem *item in _items) {
        item.title.textColor = [Theme text];
        item.detail.textColor = [Theme secondaryText];
        item.accent.backgroundColor = [Theme colorForState:LetterStateCorrect];
    }
}
@end
