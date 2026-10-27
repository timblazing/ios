#import "T3PairingScanner.h"
#import <AVFoundation/AVFoundation.h>

static void T3StopCaptureSession(AVCaptureSession *session) {
    for (AVCaptureOutput *output in session.outputs) {
        if ([output isKindOfClass:[AVCaptureMetadataOutput class]]) {
            [(AVCaptureMetadataOutput *)output setMetadataObjectsDelegate:nil queue:NULL];
        }
    }
    [session stopRunning];
}

@interface T3PairingScanner () <AVCaptureMetadataOutputObjectsDelegate>
@property(nonatomic, copy) void (^completion)(NSString *);
@property(nonatomic) AVCaptureSession *captureSession;
@property(nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic) dispatch_queue_t captureQueue;
@property(nonatomic) UILabel *instructions;
@property(nonatomic) UIView *header;
@property(nonatomic) UIButton *closeButton;
@property(nonatomic) UILabel *titleLabel;
@property(nonatomic) CAShapeLayer *scanFrame;
@property(atomic) BOOL finished;
@end

@implementation T3PairingScanner
- (instancetype)initWithCompletion:(void (^)(NSString *))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _completion = [completion copy];
        _captureQueue = dispatch_queue_create("com.local.t3mini.scanner", DISPATCH_QUEUE_SERIAL);
        _captureSession = [AVCaptureSession new];
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1];
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.previewLayer];
    self.scanFrame = [CAShapeLayer layer];
    self.scanFrame.fillColor = [UIColor clearColor].CGColor;
    self.scanFrame.strokeColor = [UIColor colorWithRed:0.204 green:0.420 blue:0.945 alpha:1].CGColor;
    self.scanFrame.lineWidth = 3;
    [self.view.layer addSublayer:self.scanFrame];
    self.header = [UIView new];
    self.header.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.96];
    [self.view addSubview:self.header];
    self.titleLabel = [UILabel new];
    self.titleLabel.text = @"Scan pairing code";
    self.titleLabel.textColor = [UIColor colorWithWhite:0.96 alpha:1];
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.header addSubview:self.titleLabel];
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"Done" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor colorWithRed:0.204 green:0.420 blue:0.945 alpha:1]
                        forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.closeButton.accessibilityLabel = @"Close pairing scanner";
    [self.closeButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:self.closeButton];
    self.instructions = [UILabel new];
    self.instructions.text = @"Point the camera at the pairing QR code in T3 Code on your computer.";
    self.instructions.textColor = [UIColor colorWithWhite:0.96 alpha:1];
    self.instructions.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.9];
    self.instructions.font = [UIFont systemFontOfSize:16];
    self.instructions.textAlignment = NSTextAlignmentCenter;
    self.instructions.numberOfLines = 0;
    [self.view addSubview:self.instructions];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancel)
                                               name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraFailed:)
                                               name:AVCaptureSessionRuntimeErrorNotification object:self.captureSession];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraInterrupted:)
                                               name:AVCaptureSessionWasInterruptedNotification object:self.captureSession];
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.finished) return;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        [self startCamera];
    } else if (status == AVAuthorizationStatusNotDetermined) {
        __weak T3PairingScanner *weakSelf = self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                T3PairingScanner *scanner = weakSelf;
                if (!scanner || scanner.finished) return;
                if (granted) [scanner startCamera];
                else [scanner showUnavailable:@"Camera access is off. Enable it for T3 Code in Settings, or use a pairing link."];
            });
        }];
    } else {
        [self showUnavailable:@"Camera access is off. Enable it for T3 Code in Settings, or use a pairing link."];
    }
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self finish:nil];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    self.previewLayer.frame = bounds;
    AVCaptureConnection *connection = self.previewLayer.connection;
    if (connection.isVideoOrientationSupported) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (orientation != UIInterfaceOrientationUnknown) connection.videoOrientation = (AVCaptureVideoOrientation)orientation;
    }
    self.header.frame = CGRectMake(0, 0, bounds.size.width, 64);
    self.closeButton.frame = CGRectMake(bounds.size.width - 88, 10, 80, 44);
    self.titleLabel.frame = CGRectMake(88, 10, MAX(0, bounds.size.width - 176), 44);
    CGFloat width = MIN(480, MAX(0, bounds.size.width - 48));
    self.instructions.frame = CGRectMake((bounds.size.width - width) / 2, bounds.size.height - 124, width, 96);
    CGFloat side = MIN(360, MIN(bounds.size.width - 64, bounds.size.height - 240));
    CGRect rect = CGRectMake((bounds.size.width - side) / 2, 80 + (bounds.size.height - 240 - side) / 2, side, side);
    self.scanFrame.path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:18].CGPath;
}
- (void)startCamera {
    AVCaptureSession *session = self.captureSession;
    __weak T3PairingScanner *weakSelf = self;
    dispatch_async(self.captureQueue, ^{
        T3PairingScanner *scanner = weakSelf;
        if (!scanner || scanner.finished) return;
        BOOL configured = NO;
        for (AVCaptureOutput *output in session.outputs) {
            if ([output isKindOfClass:[AVCaptureMetadataOutput class]] &&
                [[(AVCaptureMetadataOutput *)output metadataObjectTypes] containsObject:AVMetadataObjectTypeQRCode]) {
                configured = YES;
            }
        }
        if (!configured) {
            AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            NSError *error = nil;
            AVCaptureDeviceInput *input = camera ? [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error] : nil;
            AVCaptureMetadataOutput *output = [AVCaptureMetadataOutput new];
            [session beginConfiguration];
            if ([session canSetSessionPreset:AVCaptureSessionPreset640x480]) session.sessionPreset = AVCaptureSessionPreset640x480;
            else if ([session canSetSessionPreset:AVCaptureSessionPresetMedium]) session.sessionPreset = AVCaptureSessionPresetMedium;
            if (input && [session canAddInput:input] && [session canAddOutput:output]) {
                [session addInput:input];
                [session addOutput:output];
                if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
                    output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
                    [output setMetadataObjectsDelegate:scanner queue:dispatch_get_main_queue()];
                    configured = YES;
                }
            }
            [session commitConfiguration];
        }
        if (configured && !scanner.finished) {
            [session startRunning];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf.finished) [weakSelf.view setNeedsLayout];
            });
        } else if (!scanner.finished) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf showUnavailable:@"The camera is unavailable. Close this screen and use a pairing link instead."];
            });
        }
    });
}
- (void)showUnavailable:(NSString *)message {
    if (self.finished) return;
    self.instructions.text = message;
    self.scanFrame.hidden = YES;
    self.previewLayer.hidden = YES;
    AVCaptureSession *session = self.captureSession;
    dispatch_async(self.captureQueue, ^{ T3StopCaptureSession(session); });
}
- (void)cameraFailed:(NSNotification *)notification {
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUnavailable:@"The camera stopped. Close this screen and try again, or use a pairing link."];
    });
}
- (void)cameraInterrupted:(NSNotification *)notification {
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUnavailable:@"The camera was interrupted. Close this screen and try again."];
    });
}
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)objects
      fromConnection:(AVCaptureConnection *)connection {
    (void)output; (void)connection;
    if (self.finished) return;
    for (AVMetadataObject *object in objects) {
        if (![object.type isEqualToString:AVMetadataObjectTypeQRCode] || ![object isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) continue;
        NSString *payload = [(AVMetadataMachineReadableCodeObject *)object stringValue];
        if (payload.length) { [self finish:payload]; break; }
    }
}
- (void)cancel { [self finish:nil]; }
- (void)finish:(NSString *)payload {
    if (self.finished) return;
    self.finished = YES;
    AVCaptureSession *session = self.captureSession;
    dispatch_async(self.captureQueue, ^{ T3StopCaptureSession(session); });
    void (^completion)(NSString *) = self.completion;
    self.completion = nil;
    if (completion) completion(payload);
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AVCaptureSession *session = _captureSession;
    dispatch_async(_captureQueue, ^{ T3StopCaptureSession(session); });
}
@end
