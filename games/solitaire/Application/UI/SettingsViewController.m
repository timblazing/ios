#import "SettingsViewController.h"
// Felt greens and the gold accent from the board and controls bar.
static UIColor *Felt(void) {
    return [UIColor colorWithRed:0.035 green:0.2 blue:0.085 alpha:1];
}
static UIColor *Row(void) {
    return [UIColor colorWithRed:0.07 green:0.3 blue:0.14 alpha:1];
}
static UIColor *Gold(void) {
    return [UIColor colorWithRed:1 green:0.82 blue:0.25 alpha:1];
}
@implementation SettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.tableView.backgroundColor = Felt();
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.15];
    self.tableView.rowHeight = 64;
    UINavigationBar *bar = self.navigationController.navigationBar;
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = NO;
    bar.barTintColor = [UIColor colorWithRed:0.02 green:0.13 blue:0.06 alpha:1];
    bar.tintColor = Gold();
    bar.titleTextAttributes = @{
        NSForegroundColorAttributeName : [UIColor whiteColor],
        NSFontAttributeName : [UIFont fontWithName:@"AvenirNext-DemiBold" size:18]
    };
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(done)];
}
- (void)done {
    [self dismissViewControllerAnimated:YES completion:self.onClose];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 3 : 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Statistics" : @"Celebration";
}
- (void)tableView:(UITableView *)tableView
    willDisplayHeaderView:(UIView *)view
               forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]])
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = [UIColor colorWithWhite:1 alpha:0.75];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:nil];
    cell.backgroundColor = Row();
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont fontWithName:@"AvenirNext-Medium" size:17];
    if (indexPath.section == 1) {
        cell.textLabel.text = @"Preview celebration";
        cell.textLabel.textColor = Gold();
        cell.textLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:17];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        UIView *selected = [UIView new];
        selected.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.19 alpha:1];
        cell.selectedBackgroundView = selected;
        return cell;
    }
    cell.detailTextLabel.textColor = Gold();
    cell.detailTextLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:22];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSArray *keys = @[ @"gamesPlayed", @"wins", @"winStreak" ];
    cell.textLabel.text = @[ @"Games played", @"Wins", @"Current win streak" ][indexPath.row];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)[d integerForKey:keys[indexPath.row]]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1)
        return;
    void (^close)(void) = self.onClose, (^preview)(void) = self.onPreviewCelebration;
    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 if (close)
                                     close();
                                 if (preview)
                                     preview();
                             }];
}
@end
