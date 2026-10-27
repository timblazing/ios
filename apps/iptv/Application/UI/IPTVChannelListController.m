#import "IPTVChannelListController.h"
#import "IPTVPlayerController.h"
#import "../Stream/IPTVPlaylist.h"

static NSString *const IPTVServerDefault = @"server.baseURL";

@implementation IPTVChannelListController {
    NSArray<NSDictionary *> *_groups;
}

- (instancetype)init {
    return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TV";
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.tableView.rowHeight = 56;
    UIBarButtonItem *server = [[UIBarButtonItem alloc] initWithTitle:@"Server" style:UIBarButtonItemStylePlain target:self action:@selector(editServer)];
    server.accessibilityLabel = @"Server settings";
    self.navigationItem.rightBarButtonItem = server;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![NSUserDefaults.standardUserDefaults stringForKey:IPTVServerDefault].length) [self editServer];
    else if (!_groups) [self reload];
}

- (void)editServer {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Server" message:@"Dispatcharr base URL" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"http://192.168.1.x:9191";
        field.text = [NSUserDefaults.standardUserDefaults stringForKey:IPTVServerDefault];
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *s = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (s.length && ![s containsString:@"://"]) s = [@"http://" stringByAppendingString:s];
        while ([s hasSuffix:@"/"]) s = [s substringToIndex:s.length - 1];
        [NSUserDefaults.standardUserDefaults setObject:s forKey:IPTVServerDefault];
        [self reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMessage:(NSString *)message {
    UILabel *label = [UILabel new];
    label.text = message;
    label.textColor = [UIColor colorWithWhite:0.7 alpha:1];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    self.tableView.backgroundView = message ? label : nil;
}

- (void)reload {
    NSString *base = [NSUserDefaults.standardUserDefaults stringForKey:IPTVServerDefault];
    NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/output/m3u"]];
    if (!url) {
        [self showMessage:@"Set the server address with the Server button."];
        return;
    }
    [self showMessage:@"Loading channels..."];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 10;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *r, NSError *error) {
        NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSArray *channels = text ? [IPTVPlaylist channelsFromM3U:text baseURL:url] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_groups = [IPTVPlaylist groupedChannels:channels];
            [self.tableView reloadData];
            [self showMessage:channels.count ? nil : [NSString stringWithFormat:@"No channels. %@", error.localizedDescription ?: @""]];
        });
    }] resume];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _groups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_groups[section][@"channels"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _groups[section][@"title"];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        header.contentView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        header.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    IPTVChannel *channel = _groups[indexPath.section][@"channels"][indexPath.row];
    cell.backgroundColor = [UIColor colorWithWhite:0.11 alpha:1];
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.text = channel.number.length ? [NSString stringWithFormat:@"%@  %@", channel.number, channel.name] : channel.name;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IPTVChannel *channel = _groups[indexPath.section][@"channels"][indexPath.row];
    [self presentViewController:[[IPTVPlayerController alloc] initWithChannel:channel] animated:YES completion:nil];
}
@end
