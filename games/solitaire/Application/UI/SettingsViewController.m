#import "SettingsViewController.h"
@implementation SettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.tableView.backgroundColor = [UIColor colorWithRed:0.039 green:0.035 blue:0.055 alpha:1];
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.08];
    self.tableView.rowHeight = 64;
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.071 green:0.063 blue:0.11 alpha:1];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.937 green:0.788 blue:0.396 alpha:1];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(done)];
}
- (void)done {
    [self dismissViewControllerAnimated:YES completion:self.onClose];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Statistics";
}
- (void)tableView:(UITableView *)tableView
    willDisplayHeaderView:(UIView *)view
               forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]])
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = [UIColor colorWithWhite:1 alpha:0.45];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithRed:0.071 green:0.063 blue:0.11 alpha:1];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.937 green:0.788 blue:0.396 alpha:1];
    cell.detailTextLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:22];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSArray *keys = @[ @"gamesPlayed", @"wins", @"winStreak" ];
    cell.textLabel.text = @[ @"Games played", @"Wins", @"Current win streak" ][indexPath.row];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)[d integerForKey:keys[indexPath.row]]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}
@end
