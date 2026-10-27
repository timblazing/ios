#import "GameViewController.h"
#import "Game/PuzzleCalendar.h"
#import "Game/WordleGame.h"
#import "Game/WordleStats.h"
#import "Services/WordSource.h"
#import "UI/BoardView.h"
#import "UI/Icons.h"
#import "UI/KeyboardView.h"
#import "UI/Panels.h"
#import "UI/Theme.h"

static NSString *const PracticeModeKey = @"practiceMode", *const DailyKey = @"daily", *const PracticeKey = @"practice",
                       *const StatsKey = @"stats", *const SeenHelpKey = @"seenHelp";
static const CGFloat HeaderHeight = 60;

@implementation GameViewController {
    UIView *_header, *_headerLine, *_toaster;
    UILabel *_title, *_caption;
    NSArray<UIButton *> *_headerButtons;
    BoardView *_board;
    KeyboardView *_keyboard;
    Panel *_panel;
    NSMutableArray<UIView *> *_toasts;
    UIView *_stickyToast;

    WordleGame *_game;
    WordleStats *_stats;
    NSMutableString *_current;
    BOOL _practice, _revealing, _loading;
    NSInteger _day, _loadToken;
    UITextChecker *_checker;
    NSString *_language;
}

#pragma mark - Setup

- (void)viewDidLoad {
    [super viewDidLoad];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [Theme setDark:[defaults boolForKey:@"darkTheme"] highContrast:[defaults boolForKey:@"highContrast"]];
    _stats = [[WordleStats alloc] initWithDictionary:[defaults dictionaryForKey:StatsKey] ?: @{}];
    _current = [NSMutableString string];
    _toasts = [NSMutableArray array];
    _checker = [UITextChecker new];
    for (NSString *language in @[ @"en_US", @"en_GB", @"en" ])
        if ([[UITextChecker availableLanguages] containsObject:language]) {
            _language = language;
            break;
        }
    if (!_language)
        for (NSString *language in [UITextChecker availableLanguages])
            if ([language hasPrefix:@"en"]) {
                _language = language;
                break;
            }

    _header = [UIView new];
    [self.view addSubview:_header];
    _title = [UILabel new];
    _title.text = @"Wordle";
    _title.font = [Theme titleFontOfSize:34];
    _title.textAlignment = NSTextAlignmentCenter;
    _title.accessibilityTraits = UIAccessibilityTraitHeader;
    [_header addSubview:_title];
    NSMutableArray *buttons = [NSMutableArray array];
    NSArray *specs = @[
        @[ @"menu", @"Menu", NSStringFromSelector(@selector(showMenu)) ],
        @[ @"help", @"How to play", NSStringFromSelector(@selector(showHelp)) ],
        @[ @"stats", @"Statistics", NSStringFromSelector(@selector(showStats)) ],
        @[ @"settings", @"Settings", NSStringFromSelector(@selector(showSettings)) ]
    ];
    for (NSArray *spec in specs) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setImage:Icon(spec[0]) forState:UIControlStateNormal];
        button.accessibilityLabel = spec[1];
        [button addTarget:self action:NSSelectorFromString(spec[2]) forControlEvents:UIControlEventTouchUpInside];
        [_header addSubview:button];
        [buttons addObject:button];
    }
    _headerButtons = buttons;
    _headerLine = [UIView new];
    [_header addSubview:_headerLine];
    _caption = [UILabel new];
    _caption.font = [Theme boldFontOfSize:12];
    _caption.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_caption];

    _board = [BoardView new];
    [self.view addSubview:_board];
    _keyboard = [KeyboardView new];
    __weak GameViewController *weakSelf = self;
    _keyboard.onKey = ^(NSString *key) {
        [weakSelf typeKey:key];
    };
    [self.view addSubview:_keyboard];
    _toaster = [UIView new];
    _toaster.userInteractionEnabled = NO;
    [self.view addSubview:_toaster];
    [self applyTheme];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(refreshDay)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
    // Posted at midnight, among other times, so the daily puzzle rolls over while the app is open.
    [center addObserver:self
               selector:@selector(refreshDay)
                   name:UIApplicationSignificantTimeChangeNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(save)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];

    if ([defaults boolForKey:PracticeModeKey])
        [self openPractice:NO keepFinished:YES];
    else
        [self loadDaily];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:SeenHelpKey]) {
        [defaults setBool:YES forKey:SeenHelpKey];
        [self showHelp];
    }
#ifdef WORDLE_DEBUG
    // Simulator-only driver for screenshots: WORDLE_TYPE="crane,slate," types (a comma is Enter),
    // WORDLE_PANEL opens a panel afterwards.
    NSDictionary *env = [NSProcessInfo processInfo].environment;
    if (env[@"WORDLE_PRACTICE"])
        [self openPractice:YES keepFinished:NO];
    NSString *typed = env[@"WORDLE_TYPE"] ?: @"";
    for (NSUInteger i = 0; i < typed.length; i++) {
        NSString *c = [typed substringWithRange:NSMakeRange(i, 1)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.5 + i * 0.12 + (i / 6) * 2.0) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           [self typeKey:[c isEqualToString:@","] ? KeyEnter : c.uppercaseString];
                       });
    }
    NSString *panel = env[@"WORDLE_PANEL"];
    if (panel)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.5 + typed.length * 0.5) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           [self->_panel dismiss];
                           [self performSelector:NSSelectorFromString(panel)];
                       });
#endif
}
- (BOOL)prefersStatusBarHidden {
    return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    _header.frame = CGRectMake(0, 0, size.width, HeaderHeight);
    _headerLine.frame = CGRectMake(0, HeaderHeight - 1, size.width, 1);
    _title.frame = CGRectMake(120, 0, size.width - 240, HeaderHeight - 1);
    CGFloat side = 12, y = round((HeaderHeight - 44) / 2);
    _headerButtons[0].frame = CGRectMake(side, y, 44, 44);
    for (NSUInteger i = 1; i < 4; i++)
        _headerButtons[i].frame = CGRectMake(size.width - side - (4 - i) * 44, y, 44, 44);

    CGFloat keyHeight = 58, keyboardWidth = MIN(size.width - 16, 600);
    CGFloat keyboardHeight = [KeyboardView heightForKeyHeight:keyHeight];
    _keyboard.frame = CGRectMake(round((size.width - keyboardWidth) / 2), size.height - keyboardHeight - 10,
                                 keyboardWidth, keyboardHeight);

    CGFloat top = HeaderHeight + 28, bottom = CGRectGetMinY(_keyboard.frame) - 20;
    _caption.frame = CGRectMake(0, HeaderHeight + 6, size.width, 16);
    CGFloat gap = 6;
    CGFloat tile = floor(MIN(MIN(68, (bottom - top - 5 * gap) / 6), (size.width - 32 - 4 * gap) / 5));
    _board.tileSize = tile;
    _board.gap = gap;
    CGSize boardSize = [_board boardSize];
    _board.frame = CGRectMake(round((size.width - boardSize.width) / 2),
                              round(top + (bottom - top - boardSize.height) / 2), boardSize.width, boardSize.height);
    [_board setNeedsLayout];
    _toaster.frame = CGRectMake(0, HeaderHeight + 24, size.width, 300);
    [self layoutToasts];
}
- (void)applyTheme {
    self.view.backgroundColor = [Theme background];
    _header.backgroundColor = [Theme background];
    _headerLine.backgroundColor = [Theme emptyBorder];
    _title.textColor = [Theme text];
    _caption.textColor = [Theme secondaryText];
    for (UIButton *button in _headerButtons)
        button.tintColor = [Theme text];
    [_board applyTheme];
    [_keyboard applyTheme];
    [_panel applyTheme];
    for (UIView *toast in _toasts)
        [self styleToast:toast];
}

#pragma mark - Loading puzzles

- (NSInteger)today {
    return [PuzzleCalendar dayForDate:[NSDate date]];
}
- (void)refreshDay {
    if (_revealing)
        return;
    if (!_practice && _day != [self today])
        [self loadDaily];
    else if (!_game && !_loading)
        _practice ? [self openPractice:NO keepFinished:YES] : [self loadDaily];
}
- (void)loadDaily {
    _practice = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PracticeModeKey];
    NSInteger today = [self today];
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:DailyKey];
    NSArray *guesses = [saved[@"day"] integerValue] == today ? saved[@"guesses"] : @[];
    [self startDay:today guesses:guesses];
    [[WordSource shared] prefetchFromDay:today count:15];
}
// Resumes the saved practice puzzle (a finished one only if keepFinished), otherwise fetches a new one.
- (void)openPractice:(BOOL)forceNew keepFinished:(BOOL)keepFinished {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:PracticeKey];
    NSInteger day = saved ? [saved[@"day"] integerValue] : -1;
    NSString *answer = saved ? [[WordSource shared] cachedSolutionForDay:day] : nil;
    WordleGame *resumed = answer ? [[WordleGame alloc] initWithAnswer:answer guesses:saved[@"guesses"]] : nil;
    _practice = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PracticeModeKey];
    if (resumed && !forceNew && (!resumed.over || keepFinished)) {
        [self startDay:day guesses:resumed.guesses];
        return;
    }
    NSInteger token = [self resetBoard];
    _day = -1;
    _loading = YES;
    [self updateCaption];
    UIView *loading = [self toast:@"Finding a puzzle…" duration:0];
    [[WordSource shared] randomDayBefore:[self today]
                               excluding:day
                              completion:^(NSInteger newDay, NSString *word) {
                                  if (token != self->_loadToken)
                                      return;
                                  self->_loading = NO;
                                  [self removeToast:loading];
                                  if (newDay < 0) {
                                      self->_stickyToast =
                                          [self toast:@"Practice puzzles need Wi-Fi. Today's Wordle is in the menu."
                                             duration:0];
                                      return;
                                  }
                                  [self startDay:newDay guesses:@[]];
                              }];
}
- (NSInteger)resetBoard {
    [self removeToast:_stickyToast];
    _stickyToast = nil;
    _game = nil;
    _revealing = NO;
    [_current setString:@""];
    [_board reset];
    [_keyboard setStates:@{} animated:NO];
    return ++_loadToken;
}
- (void)startDay:(NSInteger)day guesses:(NSArray *)guesses {
    NSInteger token = [self resetBoard];
    _day = day;
    [self updateCaption];
    NSString *answer = [[WordSource shared] cachedSolutionForDay:day];
    if (answer) {
        [self beginWithAnswer:answer guesses:guesses];
        return;
    }
    _loading = YES;
    UIView *loading = [self toast:@"Loading today's Wordle…" duration:0];
    [[WordSource shared] solutionForDay:day
                             completion:^(NSString *word) {
                                 if (token != self->_loadToken)
                                     return;
                                 self->_loading = NO;
                                 [self removeToast:loading];
                                 if (word)
                                     [self beginWithAnswer:word guesses:guesses];
                                 else
                                     self->_stickyToast =
                                         [self toast:@"Couldn't load today's Wordle. Connect to Wi-Fi and try again."
                                            duration:0];
                             }];
}
- (void)beginWithAnswer:(NSString *)answer guesses:(NSArray *)guesses {
    _game = [[WordleGame alloc] initWithAnswer:answer guesses:[guesses isKindOfClass:[NSArray class]] ? guesses : @[]];
    if (_game.guesses.count || _game.over)
        [_current setString:@""];
    for (NSUInteger row = 0; row < _game.guesses.count; row++) {
        [_board setLetters:_game.guesses[row] inRow:row];
        [_board setStates:[_game evaluationForRow:row] inRow:row];
    }
    if (!_game.over)
        [_board setLetters:_current inRow:_game.guesses.count];
    [_keyboard setStates:[_game keyStates] animated:NO];
    [self save];
    if (_game.over) {
        if (_game.lost)
            _stickyToast = [self toast:_game.answer duration:0];
        NSInteger token = _loadToken;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (token == self->_loadToken && !self->_panel && self.view.window)
                [self showStats];
        });
    }
}
- (void)updateCaption {
    _caption.text = _practice && _day >= 0 ? [NSString stringWithFormat:@"PRACTICE · NO. %@", PuzzleNumber(_day)]
                    : _practice           ? @"PRACTICE"
                                          : nil;
}
- (void)save {
    if (!_game)
        return;
    [[NSUserDefaults standardUserDefaults] setObject:@{@"day" : @(_day), @"guesses" : _game.guesses}
                                              forKey:_practice ? PracticeKey : DailyKey];
}

#pragma mark - Input

- (BOOL)canBecomeFirstResponder {
    return YES;
}
// A hardware keyboard works too.
- (NSArray<UIKeyCommand *> *)keyCommands {
    static NSArray *commands;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *list = [NSMutableArray array];
        for (unichar c = 'a'; c <= 'z'; c++)
            [list addObject:[UIKeyCommand keyCommandWithInput:[NSString stringWithCharacters:&c length:1]
                                                modifierFlags:0
                                                       action:@selector(hardwareKey:)]];
        [list addObject:[UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:0 action:@selector(hardwareKey:)]];
        [list addObject:[UIKeyCommand keyCommandWithInput:@"\b" modifierFlags:0 action:@selector(hardwareKey:)]];
        commands = list;
    });
    return commands;
}
- (void)hardwareKey:(UIKeyCommand *)command {
    NSString *input = command.input;
    [self typeKey:[input isEqualToString:@"\r"] ? KeyEnter
                  : [input isEqualToString:@"\b"] ? KeyDelete
                                                  : input.uppercaseString];
}
- (NSUInteger)currentRow {
    return _game ? _game.guesses.count : 0;
}
- (void)typeKey:(NSString *)key {
    if (_panel || _revealing || _game.over)
        return;
    NSUInteger row = [self currentRow];
    if ([key isEqualToString:KeyEnter]) {
        [self submit];
    } else if ([key isEqualToString:KeyDelete]) {
        if (!_current.length)
            return;
        [_current deleteCharactersInRange:NSMakeRange(_current.length - 1, 1)];
        [_board setLetters:_current inRow:row];
    } else if (_current.length < 5 && key.length == 1) {
        [_current appendString:key];
        [_board setLetters:_current inRow:row];
        [[_board tileAtRow:row column:_current.length - 1] pop];
    }
}
- (BOOL)isWord:(NSString *)word {
    if ([word isEqualToString:_game.answer] || [[WordSource shared] isKnownAnswer:word] || !_language)
        return YES;
    NSRange miss = [_checker rangeOfMisspelledWordInString:word.lowercaseString
                                                     range:NSMakeRange(0, word.length)
                                                startingAt:0
                                                      wrap:NO
                                                  language:_language];
    return miss.location == NSNotFound;
}
- (void)reject:(NSString *)message {
    [_board shakeRow:[self currentRow]];
    [self toast:message duration:1];
}
- (void)submit {
    if (!_game) {
        [self toast:_loading ? @"Still loading the puzzle…" : @"No puzzle loaded yet" duration:1];
        [self refreshDay];
        return;
    }
    NSString *guess = [_current copy];
    if (guess.length < 5)
        return [self reject:@"Not enough letters"];
    if (![self isWord:guess])
        return [self reject:@"Not in word list"];
    NSString *violation =
        [[NSUserDefaults standardUserDefaults] boolForKey:@"hardMode"] ? [_game hardModeViolationForGuess:guess] : nil;
    if (violation)
        return [self reject:violation];

    NSUInteger row = _game.guesses.count;
    [_game addGuess:guess];
    [_current setString:@""];
    [self save];
    if (_game.over && !_practice) {
        [_stats recordDay:_day won:_game.won guesses:_game.guesses.count];
        [[NSUserDefaults standardUserDefaults] setObject:[_stats dictionary] forKey:StatsKey];
    }
    _revealing = YES;
    NSInteger token = _loadToken;
    [_board revealRow:row
               states:[_game evaluationForRow:row]
             animated:!UIAccessibilityIsReduceMotionEnabled()
           completion:^{
               if (token != self->_loadToken)
                   return;
               self->_revealing = NO;
               [self->_keyboard setStates:[self->_game keyStates] animated:YES];
               [self finishRow:row token:token];
           }];
}
- (void)finishRow:(NSUInteger)row token:(NSInteger)token {
    if (!_game.over)
        return;
    if (_game.won) {
        NSArray *praise = @[ @"Genius", @"Magnificent", @"Impressive", @"Splendid", @"Great", @"Phew" ];
        [self toast:praise[MIN(row, 5)] duration:2];
        if (!UIAccessibilityIsReduceMotionEnabled())
            [_board bounceRow:row];
    } else {
        _stickyToast = [self toast:_game.answer duration:0];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (token == self->_loadToken && !self->_panel)
            [self showStats];
    });
}

#pragma mark - Toasts

- (void)styleToast:(UIView *)toast {
    toast.backgroundColor = [Theme text];
    ((UILabel *)toast.subviews.firstObject).textColor = [Theme background];
}
// duration 0 keeps the toast until it's removed.
- (UIView *)toast:(NSString *)text duration:(NSTimeInterval)duration {
    UIView *toast = [UIView new];
    toast.layer.cornerRadius = 4;
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [Theme boldFontOfSize:14];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    [toast addSubview:label];
    CGSize size = [label sizeThatFits:CGSizeMake(MIN(420, self.view.bounds.size.width - 64), CGFLOAT_MAX)];
    label.frame = CGRectMake(16, 16, ceil(size.width), ceil(size.height));
    toast.bounds = CGRectMake(0, 0, ceil(size.width) + 32, ceil(size.height) + 32);
    [self styleToast:toast];
    [_toaster addSubview:toast];
    [_toasts insertObject:toast atIndex:0];
    [self layoutToasts];
    [self.view bringSubviewToFront:_toaster];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
    if (duration > 0)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self removeToast:toast];
        });
    return toast;
}
- (void)removeToast:(UIView *)toast {
    if (!toast || ![_toasts containsObject:toast])
        return;
    [_toasts removeObject:toast];
    [UIView animateWithDuration:0.3
        animations:^{
            toast.alpha = 0;
        }
        completion:^(BOOL finished) {
            [toast removeFromSuperview];
            [self layoutToasts];
        }];
}
- (void)layoutToasts {
    CGFloat y = 0;
    for (UIView *toast in _toasts) {
        toast.center = CGPointMake(round(_toaster.bounds.size.width / 2), y + toast.bounds.size.height / 2);
        y += toast.bounds.size.height + 8;
    }
}

#pragma mark - Panels

- (void)present:(Panel *)panel {
    if (_revealing)
        return;
    [_panel dismiss];
    _panel = panel;
    __weak GameViewController *weakSelf = self;
    __weak Panel *weakPanel = panel;
    panel.onClose = ^{
        GameViewController *strongSelf = weakSelf;
        if (strongSelf && strongSelf->_panel == weakPanel) {
            strongSelf->_panel = nil;
            [strongSelf becomeFirstResponder];
        }
    };
    [panel showInView:self.view];
    [self.view bringSubviewToFront:_toaster];
}
- (void)showMenu {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:PracticeKey];
    NSString *answer = saved ? [[WordSource shared] cachedSolutionForDay:[saved[@"day"] integerValue]] : nil;
    WordleGame *practice = answer ? [[WordleGame alloc] initWithAnswer:answer guesses:saved[@"guesses"]] : nil;
    NSInteger resumable = practice && !practice.over && practice.guesses.count ? [saved[@"day"] integerValue] : -1;
    MenuPanel *menu = [[MenuPanel alloc] initWithToday:[self today] practice:_practice practiceDay:resumable];
    __weak MenuPanel *weakMenu = menu;
    menu.onDaily = ^{
        [weakMenu dismiss];
        if (self->_practice || self->_day != [self today])
            [self loadDaily];
    };
    menu.onPractice = ^{
        [weakMenu dismiss];
        if (!self->_practice || !self->_game || self->_game.over)
            [self openPractice:NO keepFinished:NO];
    };
    menu.onNewPractice = ^{
        [weakMenu dismiss];
        [self openPractice:YES keepFinished:NO];
    };
    [self present:menu];
}
- (void)showHelp {
    [self present:[HelpPanel new]];
}
- (void)showStats {
    BOOL won = _game.won && !_practice;
    StatsPanel *stats = [[StatsPanel alloc] initWithStats:_stats
                                                    today:[self today]
                                             highlightRow:won ? (NSInteger)_game.guesses.count - 1 : -1
                                                 gameOver:_game.over
                                                 practice:_practice];
    __weak StatsPanel *weakStats = stats;
    stats.onShare = ^{
        [self share];
    };
    stats.onNewPractice = ^{
        [weakStats dismiss];
        [self openPractice:YES keepFinished:NO];
    };
    [self present:stats];
}
- (void)showSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *key in @[ @"hardMode", @"darkTheme", @"highContrast" ])
        values[key] = @([defaults boolForKey:key]);
    SettingsPanel *settings = [[SettingsPanel alloc] initWithValues:values];
    settings.onChange = ^BOOL(NSString *key, BOOL on) {
        if ([key isEqualToString:@"hardMode"] && on && self->_game.guesses.count && !self->_game.over) {
            [self toast:@"Hard mode can only be enabled at the start of a round" duration:1.5];
            return NO;
        }
        [defaults setBool:on forKey:key];
        [Theme setDark:[defaults boolForKey:@"darkTheme"] highContrast:[defaults boolForKey:@"highContrast"]];
        [self applyTheme];
        return YES;
    };
    [self present:settings];
}

#pragma mark - Sharing

- (void)share {
    if (!_game.over)
        return;
    BOOL hard = [[NSUserDefaults standardUserDefaults] boolForKey:@"hardMode"];
    BOOL highContrast = [[NSUserDefaults standardUserDefaults] boolForKey:@"highContrast"];
    NSString *score = _game.won ? @(_game.guesses.count).stringValue : @"X";
    NSMutableString *text =
        [NSMutableString stringWithFormat:@"Wordle %@ %@/6%@%@\n", PuzzleNumber(_day), score, hard ? @"*" : @"",
                                          _practice ? @" (practice)" : @""];
    NSString *correct = highContrast ? @"🟧" : @"🟩", *present = highContrast ? @"🟦" : @"🟨";
    NSString *absent = [Theme isDark] ? @"⬛" : @"⬜";
    for (NSUInteger row = 0; row < _game.guesses.count; row++) {
        [text appendString:@"\n"];
        for (NSNumber *state in [_game evaluationForRow:row])
            [text appendString:state.integerValue == LetterStateCorrect   ? correct
                               : state.integerValue == LetterStatePresent ? present
                                                                          : absent];
    }
    [UIPasteboard generalPasteboard].string = text;
    [self toast:@"Copied results to clipboard" duration:1.5];
}
@end
