#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import "T3PairingScanner.h"

static NSString *const Service = @"com.local.t3mini.session";

@interface T3ViewController : UIViewController <WKScriptMessageHandler, WKNavigationDelegate, NSURLSessionDataDelegate>
@property(nonatomic) WKWebView *web;
@property(nonatomic) NSURLSession *session;
@property(nonatomic) NSURL *origin;
@property(nonatomic) NSDictionary *credential;
@property(nonatomic) NSString *environmentID;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) NSMutableDictionary *requests;
@property(nonatomic) NSMutableSet *reads;
@property(nonatomic) NSMutableSet *commands;
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL canWrite;
@property(nonatomic) BOOL connected;
@property(nonatomic) NSString *selectedThread;
@property(nonatomic) CGFloat keyboardHeight;
@end

@implementation T3ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.requests = [NSMutableDictionary dictionary];
    self.reads = [NSMutableSet set];
    self.commands = [NSMutableSet set];
    self.view.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1];
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    [configuration.userContentController addScriptMessageHandler:self name:@"client"];
    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.scrollView.bounces = NO;
    self.web.opaque = NO;
    self.web.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:self.web];
    NSURL *page = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
    [self.web loadFileURL:page allowingReadAccessToURL:page.URLByDeletingLastPathComponent];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)cancelConnection {
    for (NSString *commandID in self.commands) [self emit:@{@"type": @"commandError", @"commandId": commandID, @"uncertain": @YES, @"message": @"Connection paused. Refresh, then retry the same operation if needed."}];
    self.generation++;
    [self.session invalidateAndCancel];
    self.session = nil;
    [self.requests removeAllObjects]; [self.reads removeAllObjects]; [self.commands removeAllObjects];
}
- (void)background {
    self.paused = YES;
    [self cancelConnection];
    [self emit:@{@"type": @"paused"}];
}
- (void)foreground {
    if (!self.paused) return;
    self.paused = NO;
    if (self.origin && self.connected) [self connect:@{@"address": self.origin.absoluteString, @"code": @""}];
    [self emit:@{@"type": @"resumed"}];
}
- (void)memoryWarning { [self emit:@{@"type": @"memoryWarning"}]; }
- (void)keyboard:(NSNotification *)notification {
    CGRect end = [self.view convertRect:[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    self.keyboardHeight = MAX(0, self.view.bounds.size.height - MAX(0, end.origin.y));
    [self viewDidLayoutSubviews];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.web.frame = CGRectMake(0, 0, self.view.bounds.size.width, MAX(0, self.view.bounds.size.height - self.keyboardHeight));
}
- (void)emit:(NSDictionary *)event {
    NSData *data = [NSJSONSerialization dataWithJSONObject:event options:0 error:NULL];
    if (!data) return;
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    json = [[json stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"] stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
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
    NSData *data = [NSJSONSerialization dataWithJSONObject:credential options:0 error:NULL];
    OSStatus result = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: data});
    if (result != errSecItemNotFound) return result == errSecSuccess;
    query[(__bridge id)kSecValueData] = data;
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}
- (void)request:(NSString *)path body:(NSDictionary *)body form:(BOOL)form authenticated:(BOOL)authenticated completion:(void (^)(NSDictionary *, NSString *, BOOL))completion {
    if (!self.session || !self.origin) { completion(nil, @"Connect to the environment first.", NO); return; }
    if (authenticated && !self.connected) { completion(nil, @"Verifying environment identity. Reconnect will resume shortly.", NO); return; }
    if (authenticated && (![self.credential[@"token"] isKindOfClass:[NSString class]] || [self.credential[@"expires"] doubleValue] <= [NSDate date].timeIntervalSince1970)) {
        completion(nil, @"Session expired. Pair again using a fresh link.", NO); return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path relativeToURL:self.origin]];
    request.timeoutInterval = 25;
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (authenticated) {
        [request setValue:[@"Bearer " stringByAppendingString:self.credential[@"token"]] forHTTPHeaderField:@"Authorization"];
        [request setValue:@"2" forHTTPHeaderField:@"x-t3-orchestration-protocol"];
    }
    if (body) {
        request.HTTPMethod = @"POST";
        if (form) {
            NSURLComponents *components = [NSURLComponents new];
            NSMutableArray *items = [NSMutableArray array];
            for (NSString *key in body) [items addObject:[NSURLQueryItem queryItemWithName:key value:body[key]]];
            components.queryItems = items;
            request.HTTPBody = [[components.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"] dataUsingEncoding:NSUTF8StringEncoding];
        } else request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
        [request setValue:form ? @"application/x-www-form-urlencoded" : @"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    self.requests[@(task.taskIdentifier)] = [@{@"data": [NSMutableData data], @"completion": [completion copy], @"write": @(!form && body != nil), @"path": path} mutableCopy];
    [task resume];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (session != self.session) { completionHandler(NSURLSessionResponseCancel); return; }
    NSMutableDictionary *state = self.requests[@(task.taskIdentifier)];
    state[@"status"] = @([(NSHTTPURLResponse *)response statusCode]);
    if (response.expectedContentLength > 8 * 1024 * 1024) { state[@"oversize"] = @YES; completionHandler(NSURLSessionResponseCancel); }
    else completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (session != self.session) return;
    NSMutableDictionary *state = self.requests[@(task.taskIdentifier)];
    NSMutableData *buffer = state[@"data"];
    if (buffer.length + data.length > 8 * 1024 * 1024) { state[@"oversize"] = @YES; [task cancel]; }
    else [buffer appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (session != self.session) return;
    NSDictionary *state = self.requests[@(task.taskIdentifier)];
    if (!state) return;
    [self.requests removeObjectForKey:@(task.taskIdentifier)];
    void (^completion)(NSDictionary *, NSString *, BOOL) = state[@"completion"];
    NSInteger status = [state[@"status"] integerValue];
    BOOL uncertain = [state[@"write"] boolValue];
    NSString *failure = nil;
    if ([state[@"oversize"] boolValue]) failure = @"Host response exceeds the 8 MB limit.";
    else if (error) failure = @"Connection interrupted. Check Wi-Fi and host availability.";
    else if (status == 401 || status == 403) { failure = @"Access denied. Pair with a fresh pairing code from your Mac."; uncertain = NO; }
    else if (status < 200 || status >= 300) failure = [NSString stringWithFormat:@"Host returned HTTP %ld. Refresh before retrying the same operation.", (long)status];
    id json = failure ? nil : [NSJSONSerialization JSONObjectWithData:state[@"data"] options:0 error:NULL];
    if (!failure && ![json isKindOfClass:[NSDictionary class]]) failure = @"Unsupported host response. Check host compatibility.";
    completion(failure ? nil : json, failure, failure ? uncertain : NO);
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
    address = [address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![address containsString:@"://"] && address.length) {
        NSURLComponents *probe = [NSURLComponents componentsWithString:[@"http://" stringByAppendingString:address]];
        NSString *host = probe.host ?: @"";
        NSCharacterSet *numeric = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
        BOOL local = [host rangeOfCharacterFromSet:numeric.invertedSet].location == NSNotFound || [host containsString:@":"] || [host hasSuffix:@".local"] || [host isEqual:@"localhost"];
        address = [(local ? @"http://" : @"https://") stringByAppendingString:address];
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:address];
    if (!components.host.length || ![@[@"https", @"http"] containsObject:components.scheme.lowercaseString] || components.user.length || components.password.length || components.query.length || components.fragment.length || (components.path.length && ![components.path isEqualToString:@"/"])) {
        [self fail:@"Enter a base address such as http://192.168.1.20:3773, without a path or credentials."]; return;
    }
    components.path = @"/";
    [self cancelConnection];
    self.origin = components.URL;
    self.credential = [self savedCredential];
    self.canWrite = [self.credential[@"scope"] isKindOfClass:[NSString class]] && [self.credential[@"scope"] containsString:@"orchestration:operate"];
    self.connected = NO;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.HTTPCookieStorage = nil;
    configuration.URLCache = nil;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    [[NSUserDefaults standardUserDefaults] setObject:self.origin.absoluteString forKey:@"lastAddress"];
    [self request:@"/.well-known/t3/environment" body:nil form:NO authenticated:NO completion:^(NSDictionary *descriptor, NSString *failure, BOOL uncertain) {
        (void)uncertain; if (failure) { [self fail:failure]; return; }
        if (![descriptor[@"environmentId"] isKindOfClass:[NSString class]] || (![descriptor[@"orchestrationProtocolVersion"] isKindOfClass:[NSNumber class]] || [descriptor[@"orchestrationProtocolVersion"] integerValue] != 2)) {
            [self fail:@"T3 Chat requires a T3 server advertising orchestration protocol 2."]; return;
        }
        self.environmentID = descriptor[@"environmentId"];
        if (self.credential && ![self.credential[@"environmentId"] isEqual:self.environmentID]) {
            [self fail:@"This address now belongs to another environment. Forget the saved connection before pairing."]; return;
        }
        [self emit:@{@"type": @"environment", @"address": self.origin.absoluteString, @"label": [descriptor[@"label"] isKindOfClass:[NSString class]] ? descriptor[@"label"] : @"T3 environment"}];
        if (!code.length) { self.connected = YES; [self emit:@{@"type": @"paired", @"canWrite": @(self.canWrite)}]; [self loadThreads]; [self loadCatalog]; return; }
        [self request:@"/oauth/token" body:@{@"grant_type": @"urn:ietf:params:oauth:grant-type:token-exchange", @"subject_token": code,
            @"subject_token_type": @"urn:t3:params:oauth:token-type:environment-bootstrap", @"requested_token_type": @"urn:ietf:params:oauth:token-type:access_token", @"scope": @"orchestration:read orchestration:operate", @"client_label": @"T3 Chat", @"client_device_type": @"tablet", @"client_os": @"iOS"} form:YES authenticated:NO completion:^(NSDictionary *token, NSString *failure, BOOL uncertain) {
            (void)uncertain; if (failure) { [self fail:failure]; return; }
            if (![token[@"access_token"] isKindOfClass:[NSString class]] || ![token[@"token_type"] isEqual:@"Bearer"] || ![token[@"expires_in"] isKindOfClass:[NSNumber class]] || [token[@"expires_in"] doubleValue] <= 0) {
                [self fail:@"The host did not issue a supported bearer session."]; return;
            }
            NSDictionary *newCredential = @{@"scope": [token[@"scope"] isKindOfClass:[NSString class]] ? token[@"scope"] : @"orchestration:read", @"token": token[@"access_token"], @"environmentId": self.environmentID, @"expires": @([NSDate date].timeIntervalSince1970 + [token[@"expires_in"] doubleValue])};
            if (![self saveCredential:newCredential]) { [self fail:@"Could not save the session securely. Unlock the iPad and pair again."]; return; }
            self.credential = newCredential;
            self.canWrite = [newCredential[@"scope"] containsString:@"orchestration:operate"];
            self.connected = YES;
            [self emit:@{@"type": @"paired", @"canWrite": @(self.canWrite)}];
            [self loadThreads]; [self loadCatalog];
        }];
    }];
}
- (NSDictionary *)pick:(NSDictionary *)source keys:(NSArray *)keys {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in keys) if (source[key]) result[key] = source[key];
    return result;
}
- (void)loadCatalog {
    if ([self.reads containsObject:@"catalog"]) return;
    [self.reads addObject:@"catalog"];
    [self request:@"/t3-chat/config" body:nil form:NO authenticated:YES completion:^(NSDictionary *catalog, NSString *failure, BOOL uncertain) {
        (void)uncertain; [self.reads removeObject:@"catalog"];
        if (failure) { if (self.canWrite) [self fail:@"Chat requires the LAN adapter with --allow-chat. Existing reading still works."]; return; }
        if ([catalog[@"providers"] isKindOfClass:[NSArray class]]) [self emit:@{@"type": @"catalog", @"providers": catalog[@"providers"]}];
    }];
}
- (void)loadThreads {
    if (self.paused) return;
    if (!self.connected && self.credential && self.origin) {
        // A wake-time discovery can fail before Wi-Fi returns. Retry identity checks, not writes.
        for (NSDictionary *state in self.requests.allValues) {
            if ([@[@"/.well-known/t3/environment", @"/oauth/token"] containsObject:state[@"path"]]) return;
        }
        [self connect:@{@"address": self.origin.absoluteString, @"code": @""}];
        return;
    }
    if ([self.reads containsObject:@"threads"]) return;
    [self.reads addObject:@"threads"];
    [self request:@"/api/orchestration/shell" body:nil form:NO authenticated:YES completion:^(NSDictionary *shell, NSString *failure, BOOL uncertain) {
        (void)uncertain; [self.reads removeObject:@"threads"];
        if (failure) { [self fail:failure]; return; }
        if (![shell[@"threads"] isKindOfClass:[NSArray class]]) { [self fail:@"Unsupported thread list response."]; return; }
        NSMutableArray *threads = [NSMutableArray array], *projects = [NSMutableArray array];
        NSArray *sorted = [shell[@"threads"] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"updatedAt" ascending:NO]]];
        for (NSDictionary *thread in sorted) {
            if (![thread isKindOfClass:[NSDictionary class]] || ![thread[@"id"] isKindOfClass:[NSString class]]) continue;
            [threads addObject:[self pick:thread keys:@[@"id", @"projectId", @"title", @"modelSelection", @"status", @"activeRunId", @"updatedAt", @"pendingRuntimeRequest"]]];
            if (threads.count == 300) break;
        }
        for (NSDictionary *project in shell[@"projects"]) {
            if (![project isKindOfClass:[NSDictionary class]]) continue;
            [projects addObject:[self pick:project keys:@[@"id", @"title", @"defaultModelSelection"]]];
            if (projects.count == 300) break;
        }
        [self emit:@{@"type": @"threads", @"threads": threads, @"projects": projects, @"canWrite": @(self.canWrite), @"address": self.origin.absoluteString}];
    }];
}
- (BOOL)validID:(NSString *)identifier {
    if (![identifier isKindOfClass:[NSString class]]) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" ];
    return identifier.length && identifier.length <= 200 && [identifier rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}
- (void)loadThread:(NSString *)threadID {
    if (self.paused || !self.connected) return;
    if (![self validID:threadID]) { [self fail:@"Unsupported thread identifier."]; return; }
    self.selectedThread = threadID;
    NSString *readKey = [@"thread:" stringByAppendingString:threadID];
    if ([self.reads containsObject:readKey]) return;
    [self.reads addObject:readKey];
    [self request:[NSString stringWithFormat:@"/api/orchestration/threads/%@/bounded", threadID] body:nil form:NO authenticated:YES completion:^(NSDictionary *snapshot, NSString *failure, BOOL uncertain) {
        (void)uncertain; [self.reads removeObject:readKey];
        if (![self.selectedThread isEqual:threadID]) return;
        if (failure) { [self fail:failure]; return; }
        id projection = snapshot[@"projection"];
        if (![projection isKindOfClass:[NSDictionary class]] || ![projection[@"visibleTurnItems"] isKindOfClass:[NSArray class]]) { [self fail:@"Unsupported conversation response."]; return; }
        NSMutableArray *items = [NSMutableArray array], *requests = [NSMutableArray array];
        NSArray *source = projection[@"visibleTurnItems"];
        NSUInteger start = source.count > 80 ? source.count - 80 : 0, remaining = 350000;
        NSMutableSet *pendingIDs = [NSMutableSet set];
        for (NSDictionary *request in projection[@"runtimeRequests"]) {
            if (![request isKindOfClass:[NSDictionary class]] || ![request[@"status"] isEqual:@"pending"]) continue;
            [requests addObject:[self pick:request keys:@[@"id", @"kind", @"status", @"responseCapability"]]];
            if (request[@"id"]) [pendingIDs addObject:request[@"id"]];
            if (requests.count == 20) break;
        }
        // Walk newest first to bound total text while retaining old pending questions.
        for (NSInteger index = (NSInteger)source.count - 1; index >= 0; index--) {
            id wrapper = source[(NSUInteger)index];
            if (![wrapper isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *item = wrapper[@"item"];
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            if ((NSUInteger)index < start && ![pendingIDs containsObject:item[@"requestId"] ?: @""]) continue;
            NSMutableDictionary *copy = [[self pick:item keys:@[@"type", @"id", @"messageId", @"title", @"status", @"text", @"input", @"output", @"requestId", @"questions", @"options", @"prompt", @"reason", @"streaming", @"fileName", @"message", @"exitCode", @"markdown", @"diffStr", @"toolName", @"appName", @"requestKind"]] mutableCopy];
            for (NSString *key in @[@"text", @"input", @"output", @"prompt", @"reason", @"message", @"markdown", @"diffStr", @"title", @"toolName", @"appName"]) {
                NSString *value = copy[key];
                if (![value isKindOfClass:[NSString class]]) { [copy removeObjectForKey:key]; continue; }
                NSUInteger limit = MIN(remaining, [key isEqual:@"text"] ? 24000 : 4000);
                if (value.length > limit) value = [[value substringToIndex:limit] stringByAppendingString:@"\n[Truncated on iPad]"];
                remaining -= MIN(remaining, value.length); copy[key] = value;
            }
            [items insertObject:copy atIndex:0];
        }
        NSDictionary *thread = [self pick:projection[@"thread"] keys:@[@"id", @"title", @"projectId", @"modelSelection", @"runtimeMode", @"interactionMode", @"status", @"activeRunId", @"latestRunId", @"lastError"]];
        [self emit:@{@"type": @"messages", @"id": threadID, @"thread": thread, @"items": items, @"requests": requests, @"hasMore": @([snapshot[@"hasMoreHistory"] boolValue] || start > 0)}];
    }];
}
- (void)command:(NSDictionary *)command {
    NSString *commandID = command[@"commandId"];
    if (![self validID:commandID]) { [self fail:@"Invalid command identifier."]; return; }
    if ([self.commands containsObject:commandID]) return;
    if (!self.canWrite || ![@[@"thread.create", @"message.dispatch", @"thread.stop", @"runtime-request.respond", @"thread.model-selection.set"] containsObject:command[@"type"]]) {
        [self emit:@{@"type": @"commandError", @"commandId": commandID, @"message": @"Pair this iPad with a fresh code from your Mac.", @"uncertain": @NO}]; return;
    }
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:command options:0 error:NULL];
    if (!encoded || encoded.length > 65536) { [self emit:@{@"type": @"commandError", @"commandId": commandID, @"message": @"This operation exceeds the 64 KB limit.", @"uncertain": @NO}]; return; }
    [self.commands addObject:commandID];
    [self request:@"/t3-chat/command" body:command form:NO authenticated:YES completion:^(NSDictionary *result, NSString *failure, BOOL uncertain) {
        [self.commands removeObject:commandID];
        if (failure) [self emit:@{@"type": @"commandError", @"commandId": commandID, @"message": failure, @"uncertain": @(uncertain)}];
        else [self emit:@{@"type": @"commandResult", @"commandId": commandID, @"result": result[@"result"] ?: @{}}];
    }];
}
- (void)scanPairing {
    if (self.presentedViewController) return;
    __weak T3ViewController *weakSelf = self;
    T3PairingScanner *scanner = [[T3PairingScanner alloc] initWithCompletion:^(NSString *payload) {
        T3ViewController *owner = weakSelf;
        [owner dismissViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled() completion:^{
            if (!payload.length) { [owner emit:@{@"type": @"scanCancelled"}]; return; }
            NSString *link = payload;
            NSURLComponents *components = [NSURLComponents componentsWithString:link];
            if ([components.scheme isEqual:@"t3code"]) {
                link = nil;
                for (NSURLQueryItem *query in components.queryItems) if ([query.name isEqual:@"pairingUrl"]) link = query.value;
            }
            if (!link.length || ![link containsString:@"://"] || ![link containsString:@"#token="]) { [owner fail:@"This QR code is not a T3 pairing link. Create one in desktop Connections settings."]; return; }
            [owner emit:@{@"type": @"connecting"}];
            [owner connect:@{@"address": @"", @"code": link}];
        }];
    }];
    [self presentViewController:scanner animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    if (!message.frameInfo.isMainFrame || !message.frameInfo.request.URL.isFileURL || ![message.body isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *body = message.body;
    NSString *operation = body[@"operation"];
    if ([operation isEqual:@"ready"]) {
        // Provisioning is owned by didFinishNavigation; do not race it with auto-connect.
        BOOL provisioned = [[NSBundle mainBundle] pathForResource:@"Pairing.local" ofType:@"plist"] != nil;
        [self emit:@{@"type": @"ready", @"address": [[NSUserDefaults standardUserDefaults] stringForKey:@"lastAddress"] ?: @"", @"autoConnect": @(!provisioned)}];
    }
    else if ([operation isEqual:@"scanPairing"]) [self scanPairing];
    else if ([operation isEqual:@"connect"]) [self connect:body];
    else if ([operation isEqual:@"command"] && [body[@"command"] isKindOfClass:[NSDictionary class]]) [self command:body[@"command"]];
    else if ([operation isEqual:@"threads"]) [self loadThreads];
    else if ([operation isEqual:@"thread"] && [body[@"id"] isKindOfClass:[NSString class]]) [self loadThread:body[@"id"]];
    else if ([operation isEqual:@"forget"]) {
        [self cancelConnection]; self.connected = NO; self.canWrite = NO;
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
    [self emit:@{@"type": @"ready", @"address": address, @"autoConnect": @NO}];
    NSDictionary *saved = [self savedCredential];
    if (saved && [saved[@"scope"] containsString:@"orchestration:operate"]) { [self connect:@{@"address": address, @"code": @""}]; return; }
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
