#import "GameViewController.h"
#import "Scenes/GameScene.h"
#import "UI/GameControls.h"
#import "UI/SettingsViewController.h"
#import <SpriteKit/SpriteKit.h>
@interface GameViewController ()
@property(nonatomic, strong) SKView *board;
@property(nonatomic, strong) GameScene *scene;
@property(nonatomic, strong) GameControls *controls;
@property(nonatomic, strong) UILabel *victory;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL showingVictory;
@end
static const CGFloat kBarHeight = 52;
@implementation GameViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.039 green:0.035 blue:0.055 alpha:1];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"soundEnabled" : @NO}];
    // v1 settings that no longer exist.
    [defaults removeObjectForKey:@"cardBack"];
    [defaults removeObjectForKey:@"drawMode"];
    self.board = [[SKView alloc] initWithFrame:self.view.bounds];
    self.board.backgroundColor = self.view.backgroundColor;
    self.board.ignoresSiblingOrder = YES;
    self.board.preferredFramesPerSecond = 60;
    self.board.multipleTouchEnabled = NO;
    [self.view addSubview:self.board];
    self.scene = [[GameScene alloc] initWithSize:self.board.bounds.size];
    self.scene.game = [SolitaireGame new];
    self.scene.bottomInset = kBarHeight;
    __weak typeof(self) weakSelf = self;
    self.scene.gameChanged = ^{
        [weakSelf updateStatus];
    };
    [self.board presentScene:self.scene];
    [self.scene preloadTextures];
    self.controls = [[GameControls alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.controls];
    [self.controls.undoButton addTarget:self
                                 action:@selector(undo)
                       forControlEvents:UIControlEventTouchUpInside];
    [self.controls.restartButton addTarget:self
                                    action:@selector(confirmNewGame)
                          forControlEvents:UIControlEventTouchUpInside];
    [self.controls.settingsButton addTarget:self
                                     action:@selector(settings)
                           forControlEvents:UIControlEventTouchUpInside];
    self.victory = [UILabel new];
    self.victory.textColor = [UIColor whiteColor];
    self.victory.textAlignment = NSTextAlignmentCenter;
    self.victory.font = [UIFont fontWithName:@"AvenirNext-Medium" size:20];
    self.victory.shadowColor = [UIColor colorWithWhite:0 alpha:0.8];
    self.victory.shadowOffset = CGSizeMake(0, 1);
    self.victory.numberOfLines = 0;
    self.victory.hidden = YES;
    [self.view addSubview:self.victory];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(background)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(foreground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [self startTimer];
    [self.scene refreshAnimated:YES];
    [self updateStatus];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    CGFloat bar = kBarHeight, boardHeight = size.height - bar;
    // The board runs full-screen so its glow continues under the translucent controls bar.
    self.board.frame = self.view.bounds;
    self.controls.frame = CGRectMake(0, boardHeight, size.width, bar);
    self.scene.size = self.board.bounds.size;
    self.victory.frame = CGRectMake(24, boardHeight * 0.48, size.width - 48, 150);
}
- (BOOL)prefersStatusBarHidden {
    return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
- (void)startTimer {
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                  target:self
                                                selector:@selector(updateStatus)
                                                userInfo:nil
                                                 repeats:YES];
}
- (void)background {
    [self.scene cancelInteraction];
    [self.scene refreshAnimated:NO];
    [self.scene.game pauseTimer];
    self.board.paused = YES;
    [self.timer invalidate];
    self.timer = nil;
}
- (void)foreground {
    [self.scene.game resumeTimer];
    self.board.paused = NO;
    [self startTimer];
    [self updateStatus];
}
- (void)updateStatus {
    NSInteger seconds = (NSInteger)self.scene.game.elapsed;
    NSString *time = [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
    self.controls.status.text =
        [NSString stringWithFormat:@"%@   •   %ld moves", time, (long)self.scene.game.moves];
    self.controls.undoButton.enabled = self.scene.game.canUndo;
    if (self.scene.game.won) {
        self.victory.hidden = NO;
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
            initWithString:@"Nicely played.\n"
                attributes:@{NSFontAttributeName : [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:44]}];
        [text appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:[NSString stringWithFormat:@"%@   ·   %ld moves\n", time,
                                                                                   (long)self.scene.game.moves]
                                             attributes:@{
                                                 NSForegroundColorAttributeName :
                                                     [UIColor colorWithRed:0.937 green:0.788 blue:0.396 alpha:1]
                                             }]];
        [text appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:@"Tap the new game button to play again"
                                             attributes:@{
                                                 NSForegroundColorAttributeName : [UIColor colorWithWhite:1 alpha:0.5],
                                                 NSFontAttributeName : [UIFont fontWithName:@"AvenirNext-Regular" size:15]
                                             }]];
        self.victory.attributedText = text;
        if (!self.showingVictory)
            [self.scene celebrate];
        self.showingVictory = YES;
    } else {
        self.victory.hidden = YES;
        self.showingVictory = NO;
    }
}
- (void)undo {
    [self.scene cancelInteraction];
    [self.scene.game undo];
    [self.scene refreshAnimated:YES];
    [self updateStatus];
}
- (void)confirmNewGame {
    [self.scene cancelInteraction];
    [self.scene refreshAnimated:NO];
    if (self.scene.game.won) {
        [self newGame];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Start a new game?"
                                                                   message:@"This replaces your current game."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Keep playing"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"New game"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                                                [self newGame];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)newGame {
    [self.scene cancelInteraction];
    [self.scene.game newGame];
    [self.scene refreshAnimated:YES];
    [self updateStatus];
}
- (void)settings {
    [self.scene cancelInteraction];
    [self.scene refreshAnimated:NO];
    SettingsViewController *settings = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    __weak typeof(self) weakSelf = self;
    settings.onClose = ^{
        [weakSelf.scene refreshAnimated:NO];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.timer invalidate];
}
@end
