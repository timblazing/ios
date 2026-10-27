#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

static NSString *const Service = @"com.local.t3mini.session";

@interface T3ViewController : UIViewController <WKScriptMessageHandler, WKNavigationDelegate, NSURLSessionTaskDelegate>
@property(nonatomic) WKWebView *web;
@property(nonatomic) NSURLSession *session;
@property(nonatomic) NSURL *origin;
@property(nonatomic) NSDictionary *credential;
@property(nonatomic) NSString *environmentID;
@property(nonatomic) NSUInteger generation;
@end

@implementation T3ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    [configuration.userContentController addScriptMessageHandler:self name:@"client"];
    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.scrollView.bounces = NO;
    [self.view addSubview:self.web];
    NSURL *page = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
    [self.web loadFileURL:page allowingReadAccessToURL:page.URLByDeletingLastPathComponent];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)background {
    self.generation++;
    [self.session invalidateAndCancel];
    self.session = nil;
    [self emit:@{@"type": @"error", @"message": @"Paused while in background. Tap Connect when you return."}];
}
- (void)emit:(NSDictionary *)event {
    NSData *data = [NSJSONSerialization dataWithJSONObject:event options:0 error:NULL];
    if (!data) return;
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.web evaluateJavaScript:[NSString stringWithFormat:@"window.receive(%@)", json] completionHandler:nil];
    });
}
- (void)fail:(NSString *)message { [self emit:@{@"type": @"error", @"message": message}]; }
- (NSMutableDictionary *)keyQuery {
    return [@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService: Service,
              (__bridge id)kSecAttrAccount: self.origin.absoluteString ?: @""} mutableCopy];
}
- (NSDictionary *)savedCredential {
    NSMutableDictionary *query = [self keyQuery];
    query[(__bridge id)kSecReturnData] = @YES;
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess) return nil;
    NSData *data = CFBridgingRelease(result);
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}
- (BOOL)saveCredential:(NSDictionary *)credential {
    NSMutableDictionary *query = [self keyQuery];
    SecItemDelete((__bridge CFDictionaryRef)query);
    query[(__bridge id)kSecValueData] = [NSJSONSerialization dataWithJSONObject:credential options:0 error:NULL];
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}
- (void)request:(NSString *)path form:(NSDictionary *)form authenticated:(BOOL)authenticated completion:(void (^)(NSDictionary *))completion {
    if (!self.session || !self.origin) { [self fail:@"Tap Connect to open the environment first."]; return; }
    if (authenticated && (![self.credential[@"token"] isKindOfClass:[NSString class]] || [self.credential[@"expires"] doubleValue] <= [NSDate date].timeIntervalSince1970)) {
        [self fail:@"The saved session expired. Create a fresh pairing link on your host."]; return;
    }
    NSUInteger generation = self.generation;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path relativeToURL:self.origin]];
    request.timeoutInterval = 20;
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (authenticated) {
        [request setValue:[@"Bearer " stringByAppendingString:self.credential[@"token"]] forHTTPHeaderField:@"Authorization"];
        [request setValue:@"2" forHTTPHeaderField:@"x-t3-orchestration-protocol"];
    }
    if (form) {
        request.HTTPMethod = @"POST";
        NSURLComponents *components = [NSURLComponents new];
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *key in form) [items addObject:[NSURLQueryItem queryItemWithName:key value:form[key]]];
        components.queryItems = items;
        NSString *body = [components.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
        request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.generation) return;
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            if (error) { [self fail:@"Could not reach the host. Check Wi-Fi, its address, and certificate trust."]; return; }
            if (status == 401 || status == 403) { [self fail:@"Access denied. Use a fresh pairing link with conversation read access."]; return; }
            if (status < 200 || status >= 300) { [self fail:[NSString stringWithFormat:@"Host returned HTTP %ld. Check the address and server version.", (long)status]]; return; }
            if (data.length > 8 * 1024 * 1024) { [self fail:@"The response is too large for this prototype."]; return; }
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (![json isKindOfClass:[NSDictionary class]]) { [self fail:@"The host returned an unsupported response."]; return; }
            completion(json);
        });
    }] resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    (void)session; (void)task; (void)response; (void)request;
    // Never forward pairing or session credentials through a redirect.
    completionHandler(nil);
}
- (void)connect:(NSDictionary *)message {
    NSString *address = [message[@"address"] isKindOfClass:[NSString class]] ? message[@"address"] : @"";
    NSString *code = [message[@"code"] isKindOfClass:[NSString class]] ? message[@"code"] : @"";
    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *link = [code containsString:@"://"] ? code : ([address containsString:@"#token="] ? address : nil);
    if (link) {
        NSURLComponents *pairing = [NSURLComponents componentsWithString:link];
        NSURLComponents *fragment = [NSURLComponents new];
        fragment.percentEncodedQuery = pairing.percentEncodedFragment;
        code = @"";
        for (NSURLQueryItem *item in fragment.queryItems) if ([item.name isEqual:@"token"]) code = item.value ?: @"";
        NSString *hostedAddress = nil;
        for (NSURLQueryItem *item in pairing.queryItems) if ([item.name isEqual:@"host"]) hostedAddress = item.value;
        if (hostedAddress && [pairing.host isEqual:@"app.t3.codes"] && [pairing.scheme isEqual:@"https"]) address = hostedAddress;
        else {
            pairing.path = @"/"; pairing.query = nil; pairing.fragment = nil;
            address = pairing.string ?: @"";
        }
        if (!code.length) { [self fail:@"The pairing link must contain a token fragment. Create a fresh link on the host."]; return; }
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:[address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    if (!components.host.length || ![@[@"https", @"http"] containsObject:components.scheme.lowercaseString] || components.user.length || components.password.length || components.query.length || components.fragment.length || (components.path.length && ![components.path isEqualToString:@"/"])) {
        [self fail:@"Enter a base address such as http://192.168.1.20:3773, without a path or credentials."]; return;
    }
    components.path = @"/";
    self.generation++;
    [self.session invalidateAndCancel];
    self.origin = components.URL;
    self.credential = [self savedCredential];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.HTTPCookieStorage = nil;
    configuration.URLCache = nil;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    [[NSUserDefaults standardUserDefaults] setObject:self.origin.absoluteString forKey:@"lastAddress"];
    [self request:@"/.well-known/t3/environment" form:nil authenticated:NO completion:^(NSDictionary *descriptor) {
        if (![descriptor[@"environmentId"] isKindOfClass:[NSString class]] || (![descriptor[@"orchestrationProtocolVersion"] isKindOfClass:[NSNumber class]] || [descriptor[@"orchestrationProtocolVersion"] integerValue] != 2)) {
            [self fail:@"This prototype requires a T3 server advertising orchestration protocol 2."]; return;
        }
        self.environmentID = descriptor[@"environmentId"];
        if (self.credential && ![self.credential[@"environmentId"] isEqual:self.environmentID]) {
            [self fail:@"This address now belongs to another environment. Forget the saved connection before pairing."]; return;
        }
        [self emit:@{@"type": @"environment", @"label": [descriptor[@"label"] isKindOfClass:[NSString class]] ? descriptor[@"label"] : @"T3 environment"}];
        if (!code.length) { [self loadThreads]; return; }
        [self request:@"/oauth/token" form:@{@"grant_type": @"urn:ietf:params:oauth:grant-type:token-exchange", @"subject_token": code,
            @"subject_token_type": @"urn:t3:params:oauth:token-type:environment-bootstrap", @"requested_token_type": @"urn:ietf:params:oauth:token-type:access_token", @"scope": @"orchestration:read", @"client_label": @"T3 Mini", @"client_device_type": @"tablet", @"client_os": @"iOS"} authenticated:NO completion:^(NSDictionary *token) {
            if (![token[@"access_token"] isKindOfClass:[NSString class]] || ![token[@"token_type"] isEqual:@"Bearer"] || ![token[@"expires_in"] isKindOfClass:[NSNumber class]] || [token[@"expires_in"] doubleValue] <= 0) {
                [self fail:@"The host did not issue a supported bearer session."]; return;
            }
            self.credential = @{@"token": token[@"access_token"], @"environmentId": self.environmentID, @"expires": @([NSDate date].timeIntervalSince1970 + [token[@"expires_in"] doubleValue])};
            if (![self saveCredential:self.credential]) { self.credential = nil; [self fail:@"Could not save the session securely. Unlock the iPad and pair again."]; return; }
            [self emit:@{@"type": @"paired"}];
            [self loadThreads];
        }];
    }];
}
- (void)loadThreads {
    [self request:@"/api/orchestration/shell" form:nil authenticated:YES completion:^(NSDictionary *shell) {
        if (![shell[@"threads"] isKindOfClass:[NSArray class]]) { [self fail:@"Unsupported thread list response."]; return; }
        NSMutableArray *threads = [NSMutableArray array];
        for (id thread in shell[@"threads"]) {
            if (![thread isKindOfClass:[NSDictionary class]] || ![thread[@"id"] isKindOfClass:[NSString class]]) continue;
            [threads addObject:@{@"id": thread[@"id"], @"title": [thread[@"title"] isKindOfClass:[NSString class]] ? thread[@"title"] : @"Untitled"}];
            if (threads.count == 300) break;
        }
        [self emit:@{@"type": @"threads", @"threads": threads}];
    }];
}
- (void)loadThread:(NSString *)threadID {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" ];
    if (!threadID.length || threadID.length > 200 || [threadID rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound) { [self fail:@"Unsupported thread identifier."]; return; }
    [self request:[NSString stringWithFormat:@"/api/orchestration/threads/%@/bounded", threadID] form:nil authenticated:YES completion:^(NSDictionary *snapshot) {
        id projection = snapshot[@"projection"];
        if (![projection isKindOfClass:[NSDictionary class]] || ![projection[@"visibleTurnItems"] isKindOfClass:[NSArray class]]) { [self fail:@"Unsupported conversation response."]; return; }
        NSMutableArray *messages = [NSMutableArray array];
        NSArray *source = projection[@"visibleTurnItems"];
        NSUInteger start = source.count > 100 ? source.count - 100 : 0;
        for (NSUInteger index = start; index < source.count; index++) {
            id wrapper = source[index];
            if (![wrapper isKindOfClass:[NSDictionary class]]) continue;
            id item = wrapper[@"item"];
            if (![item isKindOfClass:[NSDictionary class]] || ![@[@"user_message", @"assistant_message"] containsObject:item[@"type"]] || ![item[@"text"] isKindOfClass:[NSString class]]) continue;
            NSString *body = item[@"text"];
            if (body.length > 30000) body = [[body substringToIndex:30000] stringByAppendingString:@"\n[Message truncated in this prototype]"];
            [messages addObject:@{@"role": [item[@"type"] isEqual:@"user_message"] ? @"user" : @"assistant", @"text": body}];
        }
        [self emit:@{@"type": @"messages", @"id": threadID, @"messages": messages, @"hasMore": @([snapshot[@"hasMoreHistory"] boolValue] || start > 0)}];
    }];
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    if (!message.frameInfo.isMainFrame || !message.frameInfo.request.URL.isFileURL || ![message.body isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *body = message.body;
    NSString *operation = body[@"operation"];
    if ([operation isEqual:@"ready"]) [self emit:@{@"type": @"ready", @"address": [[NSUserDefaults standardUserDefaults] stringForKey:@"lastAddress"] ?: @""}];
    else if ([operation isEqual:@"connect"]) [self connect:body];
    else if ([operation isEqual:@"threads"]) [self loadThreads];
    else if ([operation isEqual:@"thread"] && [body[@"id"] isKindOfClass:[NSString class]]) [self loadThread:body[@"id"]];
    else if ([operation isEqual:@"forget"]) {
        self.generation++; [self.session invalidateAndCancel]; self.session = nil;
        if (self.origin) SecItemDelete((__bridge CFDictionaryRef)[self keyQuery]);
        self.credential = nil;
        [self emit:@{@"type": @"forgotten"}];
    }
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)webView; (void)navigation;
    // A private install may carry a one-use provision file. Release packages exclude it.
    NSDictionary *provision = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Pairing.local" ofType:@"plist"]];
    NSString *address = [provision[@"url"] isKindOfClass:[NSString class]] ? provision[@"url"] : nil;
    NSString *token = [provision[@"token"] isKindOfClass:[NSString class]] ? provision[@"token"] : nil;
    if (!address.length || !token.length) return;
    NSURLComponents *components = [NSURLComponents componentsWithString:address];
    components.path = @"/";
    self.origin = components.URL;
    [self emit:@{@"type": @"ready", @"address": address}];
    if ([self savedCredential]) return;
    [self emit:@{@"type": @"connecting"}];
    [self connect:@{@"address": address, @"code": token}];
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    (void)webView;
    NSURL *page = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
    decisionHandler([action.request.URL.path isEqual:page.path] && action.request.URL.isFileURL ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)application; (void)options;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [T3ViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
