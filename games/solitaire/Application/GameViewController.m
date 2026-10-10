#import "GameViewController.h"
#import "Scenes/GameScene.h"
#import "UI/CelebrationView.h"
#import "UI/GameControls.h"
#import "UI/SettingsViewController.h"
#import <SpriteKit/SpriteKit.h>
@interface GameViewController ()
@property(nonatomic, strong) SKView *board;
@property(nonatomic, strong) GameScene *scene;
@property(nonatomic, strong) GameControls *controls;
@property(nonatomic, strong) CelebrationView *celebration;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL showingVictory;
@end
static const CGFloat kBarHeight = 52;
@implementation GameViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.22 blue:0.09 alpha:1];
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
    [self.controls.autoWinButton addTarget:self
                                    action:@selector(autoWin)
                          forControlEvents:UIControlEventTouchUpInside];
    self.celebration = [[CelebrationView alloc] initWithFrame:self.view.bounds];
    self.celebration.bottomInset = kBarHeight;
    [self.view addSubview:self.celebration];
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
    self.celebration.frame = self.view.bounds;
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
    self.controls.autoWinButton.hidden = !self.scene.game.canAutoWin || self.scene.autoPlaying;
    if (self.scene.game.won) {
        [self.celebration showWithTime:time moves:self.scene.game.moves];
        if (!self.showingVictory)
            [self.scene celebrate];
        self.showingVictory = YES;
    } else {
        [self.celebration hide];
        self.showingVictory = NO;
    }
}
- (void)autoWin {
    [self.scene autoWin];
    [self updateStatus];
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
