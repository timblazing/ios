#import "PaintViewController.h"
#import "PaintCanvasView.h"
#import "PaintColorBox.h"
#import "PaintColorDialog.h"
#import "PaintOptionsView.h"
#import "XPChrome.h"

static NSString *const PaintSettingsKey = @"PaintSettings";
static const CGFloat kBorder = 4, kTitleH = 36, kMenuH = 40, kStatusH = 28, kColorBoxH = 86, kToolboxW = 108;
static const int kMaxImageSide = 2048;

typedef struct { const char *name, *icon, *hint; } PaintToolInfo;
static const PaintToolInfo kTools[PaintToolCount] = {
    {"Free-Form Select", "tool-free-select", "Selects a free-form part of the picture to move, copy, or edit."},
    {"Select", "tool-select", "Selects a rectangular part of the picture to move, copy, or edit. Drag the blue corner to resize."},
    {"Eraser/Color Eraser", "tool-eraser", "Erases a portion of the picture, using the selected eraser shape."},
    {"Fill With Color", "tool-fill", "Fills an area with the current drawing color."},
    {"Pick Color", "tool-picker", "Picks up a color from the picture for drawing."},
    {"Magnifier", "tool-magnifier", "Changes the magnification. Tap to zoom in; tap again to fit."},
    {"Pencil", "tool-pencil", "Draws a free-form line one pixel wide."},
    {"Brush", "tool-brush", "Draws using a brush with the selected shape and size."},
    {"Airbrush", "tool-airbrush", "Draws using an airbrush of the selected size."},
    {"Text", "tool-text", "Inserts text into the picture. Tap or drag to place a text box."},
    {"Line", "tool-line", "Draws a straight line with the selected line width."},
    {"Curve", "tool-curve", "Draws a curved line. Drag a line, then drag twice to bend it."},
    {"Rectangle", "tool-rectangle", "Draws a rectangle with the selected fill style."},
    {"Polygon", "tool-polygon", "Draws a polygon. Tap each corner, then tap the first corner to finish."},
    {"Ellipse", "tool-ellipse", "Draws an ellipse with the selected fill style."},
    {"Rounded Rectangle", "tool-rounded-rectangle", "Draws a rounded rectangle with the selected fill style."},
};

// Sizes are in points; the canvas works in pixels (points × screen scale).
static const CGFloat kPencilSizes[] = {1, 2, 3, 4}, kLineSizes[] = {1, 2, 4, 8}, kBrushSizes[] = {3, 6, 12, 20}, kEraserSizes[] = {6, 12, 20, 32}, kAirbrushSizes[] = {10, 20, 32, 48}, kFontSizes[] = {12, 18, 28, 44}, kZoomLevels[] = {1, 2, 4, 8};
static const int kTolerances[] = {0, 32, 64, 128};
static NSString *const kToleranceNames[] = {@"Exact", @"Low", @"Med", @"High"};
typedef struct { NSString *name, *regular, *bold; } PaintFont;
static const NSInteger kFontCount = 6;

static PaintFont PaintFontAt(NSInteger i) {
    static PaintFont fonts[6];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fonts[0] = (PaintFont){@"Arial", @"ArialMT", @"Arial-BoldMT"};
        fonts[1] = (PaintFont){@"Times New Roman", @"TimesNewRomanPSMT", @"TimesNewRomanPS-BoldMT"};
        fonts[2] = (PaintFont){@"Courier New", @"CourierNewPSMT", @"CourierNewPS-BoldMT"};
        fonts[3] = (PaintFont){@"Comic", @"ChalkboardSE-Regular", @"ChalkboardSE-Bold"};
        fonts[4] = (PaintFont){@"Marker", @"MarkerFelt-Thin", @"MarkerFelt-Wide"};
        fonts[5] = (PaintFont){@"Verdana", @"Verdana", @"Verdana-Bold"};
    });
    return fonts[MAX(0, MIN(kFontCount - 1, i))];
}

// The XP Paint default palette.
static const uint32_t kDefaultPalette[28] = {
    0x000000, 0x808080, 0x800000, 0x808000, 0x008000, 0x008080, 0x000080, 0x800080, 0x808040, 0x004040, 0x0080FF, 0x004080, 0x8000FF, 0x804000,
    0xFFFFFF, 0xC0C0C0, 0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFFFF80, 0x00FF80, 0x80FFFF, 0x8080FF, 0xFF0080, 0xFF8040,
};

static uint32_t PaintHex(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 1, w = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a] && [color getWhite:&w alpha:&a]) r = g = b = w;
    return (uint32_t)lround(r * 255) << 16 | (uint32_t)lround(g * 255) << 8 | (uint32_t)lround(b * 255);
}

@interface PaintViewController () <PaintCanvasDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation PaintViewController {
    PaintCanvasView *_canvas;
    UIScrollView *_scroll;
    XPTitleGradientView *_titleBar;
    UIImageView *_appIcon;
    UILabel *_titleLabel;
    XPFlatButton *_saveButton, *_undoButton, *_redoButton;
    NSArray<XPFlatButton *> *_windowButtons;
    UIView *_menuBar;
    NSArray<XPFlatButton *> *_menuButtons;
    XPPanel *_toolbox;
    NSMutableArray<XPToolButton *> *_toolButtons;
    PaintOptionsView *_options;
    PaintColorBox *_colorBox;
    XPPanel *_statusBar;
    UILabel *_statusHint, *_statusPos, *_statusSize, *_statusZoom;
    NSArray<XPPanel *> *_statusCells;

    UIView *_menuCatcher;
    XPFlatButton *_openMenuButton;
    UIPopoverPresentationController *_popover;

    NSMutableArray<UIColor *> *_palette;
    UIColor *_primary, *_secondary;
    NSUInteger _lastSwatch;
    PaintTool _tool, _toolBeforePicker;
    NSInteger _pencil, _line, _brush, _brushShape, _eraser, _airbrush, _fillStyle, _tolerance, _zoomLevel, _font, _fontSize;
    BOOL _bold, _opaqueText, _transparentSelection, _showTools, _showColors, _showStatus, _focusMode;
    BOOL _fitZoom, _needsAutosave;
    CGFloat _keyboardInset;
    void (^_afterSave)(void);
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = XPColor(0x0831D9);
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self loadSettings];
    [self buildTitleBar];
    [self buildMenuBar];
    [self buildWorkspace];
    [self buildToolbox];
    [self buildColorBox];
    [self buildStatusBar];
    [self restoreAutosave];
    [self applySettings];
    [self selectTool:_tool];
    [self canvasDidChange:_canvas];
    _statusSize.text = [NSString stringWithFormat:@"%d × %dpx", _canvas.pixelWidth, _canvas.pixelHeight];
    _fitZoom = YES;

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self becomeFirstResponder]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [_canvas cancelTouch];
    [self closeMenu];
    BOOL fit = _fitZoom;
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { [self updateZoomLimitsFit:fit]; }];
}

- (void)appWillResignActive { [_canvas cancelTouch]; [self closeMenu]; }

// Keep the picture across launches: iOS may end the app at any time once it's in the background.
- (void)appDidEnterBackground {
    [self saveSettings];
    if (!_needsAutosave) return;
    _needsAutosave = NO;
    UIImage *image = [_canvas snapshotImage];
    NSString *path = [self autosavePath];
    UIApplication *app = UIApplication.sharedApplication;
    __block UIBackgroundTaskIdentifier task = [app beginBackgroundTaskWithExpirationHandler:^{ [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; }];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
        dispatch_async(dispatch_get_main_queue(), ^{ if (task != UIBackgroundTaskInvalid) [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; });
    });
}

- (NSString *)autosavePath { return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Untitled.png"]; }

- (void)restoreAutosave {
    NSData *data = [NSData dataWithContentsOfFile:[self autosavePath]];
    UIImage *image = data ? [UIImage imageWithData:data scale:1] : nil;
    if (image.size.width >= 1 && image.size.width <= kMaxImageSide && image.size.height >= 1 && image.size.height <= kMaxImageSide)
    {
        [_canvas resetWithPixelWidth:(int)image.size.width height:(int)image.size.height image:image];
        // A restored picture was never saved to Photos, so New should still offer to save it.
        [_canvas markUnsaved];
    }
}

#pragma mark - Settings

- (void)loadSettings {
    NSDictionary *s = [NSUserDefaults.standardUserDefaults dictionaryForKey:PaintSettingsKey] ?: @{};
    NSInteger (^num)(NSString *, NSInteger, NSInteger) = ^NSInteger(NSString *key, NSInteger fallback, NSInteger count) {
        NSNumber *n = s[key];
        NSInteger v = [n isKindOfClass:[NSNumber class]] ? n.integerValue : fallback;
        return v >= 0 && v < count ? v : fallback;
    };
    BOOL (^flag)(NSString *, BOOL) = ^BOOL(NSString *key, BOOL fallback) { NSNumber *n = s[key]; return [n isKindOfClass:[NSNumber class]] ? n.boolValue : fallback; };
    _tool = num(@"tool", PaintToolPencil, PaintToolCount);
    if (_tool == PaintToolPicker) _tool = PaintToolPencil;
    _toolBeforePicker = _tool;
    _pencil = num(@"pencil", 0, 4); _line = num(@"line", 1, 4); _brush = num(@"brush", 1, 4); _brushShape = num(@"brushShape", 0, 4);
    _eraser = num(@"eraser", 1, 4); _airbrush = num(@"airbrush", 1, 4); _fillStyle = num(@"fillStyle", 0, 3); _tolerance = num(@"tolerance", 1, 4);
    _zoomLevel = num(@"zoom", 2, 4); _font = num(@"font", 0, kFontCount); _fontSize = num(@"fontSize", 1, 4);
    _bold = flag(@"bold", NO); _opaqueText = flag(@"opaqueText", NO); _transparentSelection = flag(@"transparentSelection", NO);
    _showTools = flag(@"showTools", YES); _showColors = flag(@"showColors", YES); _showStatus = flag(@"showStatus", YES);
    _palette = [NSMutableArray array];
    NSArray *saved = s[@"palette"];
    for (NSUInteger i = 0; i < 28; i++) {
        NSNumber *n = [saved isKindOfClass:[NSArray class]] && i < saved.count ? saved[i] : nil;
        [_palette addObject:XPColor([n isKindOfClass:[NSNumber class]] ? n.unsignedIntValue : kDefaultPalette[i])];
    }
    NSNumber *p = s[@"primary"], *q = s[@"secondary"];
    _primary = XPColor([p isKindOfClass:[NSNumber class]] ? p.unsignedIntValue : 0x000000);
    _secondary = XPColor([q isKindOfClass:[NSNumber class]] ? q.unsignedIntValue : 0xFFFFFF);
}

- (void)saveSettings {
    NSMutableArray *palette = [NSMutableArray array];
    for (UIColor *color in _palette) [palette addObject:@(PaintHex(color))];
    [NSUserDefaults.standardUserDefaults setObject:@{
        @"tool": @(_tool == PaintToolPicker ? _toolBeforePicker : _tool), @"pencil": @(_pencil), @"line": @(_line), @"brush": @(_brush), @"brushShape": @(_brushShape),
        @"eraser": @(_eraser), @"airbrush": @(_airbrush), @"fillStyle": @(_fillStyle), @"tolerance": @(_tolerance), @"zoom": @(_zoomLevel),
        @"font": @(_font), @"fontSize": @(_fontSize), @"bold": @(_bold), @"opaqueText": @(_opaqueText), @"transparentSelection": @(_transparentSelection),
        @"showTools": @(_showTools), @"showColors": @(_showColors), @"showStatus": @(_showStatus),
        @"palette": palette, @"primary": @(PaintHex(_primary)), @"secondary": @(PaintHex(_secondary)),
    } forKey:PaintSettingsKey];
}

- (void)applySettings {
    CGFloat s = _canvas.pixelScale;
    _canvas.primaryColor = _primary;
    _canvas.secondaryColor = _secondary;
    _canvas.pencilWidth = kPencilSizes[_pencil] * s;
    _canvas.lineWidth = kLineSizes[_line] * s;
    _canvas.brushSize = kBrushSizes[_brush] * s;
    _canvas.brushShape = (PaintBrushShape)_brushShape;
    _canvas.eraserSize = kEraserSizes[_eraser] * s;
    _canvas.airbrushSize = kAirbrushSizes[_airbrush] * s;
    _canvas.fillStyle = (PaintFillStyle)_fillStyle;
    _canvas.fillTolerance = kTolerances[_tolerance];
    _canvas.fontName = _bold ? PaintFontAt(_font).bold : PaintFontAt(_font).regular;
    _canvas.fontSize = kFontSizes[_fontSize] * s;
    _canvas.opaqueText = _opaqueText;
    _canvas.transparentSelection = _transparentSelection;
    _colorBox.colors = _palette;
    _colorBox.primary = _primary;
    _colorBox.secondary = _secondary;
    [_colorBox reload];
    [_options refresh];
}

#pragma mark - Building the window

- (void)buildTitleBar {
    _titleBar = [XPTitleGradientView new];
    [self.view addSubview:_titleBar];
    _appIcon = [[UIImageView alloc] initWithImage:PaintIcon(@"app-palette")];
    [_titleBar addSubview:_appIcon];
    // Quick access buttons, borrowed from later Paint versions because there's no keyboard for Ctrl+Z.
    _saveButton = [self titleButton:@"qa-save" label:@"Save to Photos" action:@selector(saveToPhotos)];
    _undoButton = [self titleButton:@"qa-undo" label:@"Undo" action:@selector(undo)];
    _redoButton = [self titleButton:@"qa-redo" label:@"Redo" action:@selector(redo)];
    _titleLabel = [UILabel new];
    _titleLabel.text = @"untitled - Paint";
    _titleLabel.font = XPTitleFont(17);
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.shadowColor = XPColor(0x0A1E5A);
    _titleLabel.shadowOffset = CGSizeMake(1, 1);
    [_titleBar addSubview:_titleLabel];
    XPFlatButton *min = [self titleButton:@"win-min" label:@"Hide toolbars" action:@selector(toggleFocusMode)];
    XPFlatButton *max = [self titleButton:@"win-max" label:@"Fit picture to window" action:@selector(zoomToFit)];
    XPFlatButton *close = [self titleButton:@"win-close" label:@"New picture" action:@selector(newPicture)];
    for (XPFlatButton *b in @[min, max, close]) b.highlightColor = [UIColor colorWithWhite:1 alpha:.25];
    _windowButtons = @[min, max, close];
}

- (XPFlatButton *)titleButton:(NSString *)icon label:(NSString *)label action:(SEL)action {
    XPFlatButton *button = [XPFlatButton new];
    button.icon = PaintIcon(icon);
    button.accessibilityLabel = label;
    button.highlightColor = [UIColor colorWithWhite:1 alpha:.28];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_titleBar addSubview:button];
    return button;
}

- (void)buildMenuBar {
    _menuBar = [UIView new];
    _menuBar.backgroundColor = XPFaceColor();
    [self.view addSubview:_menuBar];
    NSMutableArray *buttons = [NSMutableArray array];
    NSArray *titles = @[@"File", @"Edit", @"View", @"Image", @"Colors", @"Help"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        XPFlatButton *button = [XPFlatButton new];
        button.title = titles[i];
        button.tag = (NSInteger)i;
        [button addTarget:self action:@selector(menuTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_menuBar addSubview:button];
        [buttons addObject:button];
    }
    _menuButtons = buttons;
}

- (void)buildWorkspace {
    _scroll = [UIScrollView new];
    _scroll.backgroundColor = XPColor(0x8C95A8);
    _scroll.delegate = self;
    _scroll.delaysContentTouches = NO;
    _scroll.panGestureRecognizer.minimumNumberOfTouches = 2;
    _scroll.maximumZoomScale = 16;
    _scroll.bouncesZoom = YES;
    _scroll.indicatorStyle = UIScrollViewIndicatorStyleBlack;
    if (@available(iOS 11.0, *)) _scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_scroll];
    CGFloat scale = UIScreen.mainScreen.scale;
    CGSize size = [self defaultCanvasSizeForSize:self.view.bounds.size];
    _canvas = [[PaintCanvasView alloc] initWithPixelWidth:(int)size.width height:(int)size.height scale:scale];
    _canvas.delegate = self;
    _canvas.layer.shadowColor = UIColor.blackColor.CGColor;
    _canvas.layer.shadowOpacity = .4;
    _canvas.layer.shadowOffset = CGSizeMake(3, 3);
    _canvas.layer.shadowRadius = 0;
    [_scroll addSubview:_canvas];
    [self resetCanvasFrame];

    UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(undo)];
    twoTap.numberOfTouchesRequired = 2;
    [_scroll addGestureRecognizer:twoTap];
    UITapGestureRecognizer *threeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(redo)];
    threeTap.numberOfTouchesRequired = 3;
    [_scroll addGestureRecognizer:threeTap];
}

- (CGSize)defaultCanvasSizeForSize:(CGSize)size { return size.width >= size.height ? CGSizeMake(1760, 1120) : CGSizeMake(1120, 1760); }

- (void)buildToolbox {
    _toolbox = [XPPanel new];
    [self.view addSubview:_toolbox];
    _toolButtons = [NSMutableArray array];
    for (NSInteger i = 0; i < PaintToolCount; i++) {
        XPToolButton *button = [XPToolButton new];
        button.icon = PaintIcon(@(kTools[i].icon));
        button.accessibilityLabel = @(kTools[i].name);
        button.tag = i;
        [button addTarget:self action:@selector(toolTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_toolbox addSubview:button];
        [_toolButtons addObject:button];
    }
    _options = [PaintOptionsView new];
    [_toolbox addSubview:_options];
}

- (void)buildColorBox {
    _colorBox = [PaintColorBox new];
    __weak PaintViewController *weakSelf = self;
    _colorBox.onPick = ^(NSUInteger index, BOOL secondary) { [weakSelf pickSwatch:index secondary:secondary]; };
    _colorBox.onSwap = ^{ [weakSelf swapColors]; };
    _colorBox.onEdit = ^{ [weakSelf editColors]; };
    [self.view addSubview:_colorBox];
}

- (void)buildStatusBar {
    _statusBar = [XPPanel new];
    [self.view addSubview:_statusBar];
    NSMutableArray<XPPanel *> *cells = [NSMutableArray array];
    for (NSInteger i = 0; i < 4; i++) {
        XPPanel *cell = [XPPanel new];
        cell.sunken = YES;
        UILabel *label = [UILabel new];
        label.font = XPFont(12);
        label.textColor = UIColor.blackColor;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:label];
        [_statusBar addSubview:cell];
        [cells addObject:cell];
    }
    _statusCells = cells;
    _statusHint = (UILabel *)cells[0].subviews[0]; _statusPos = (UILabel *)cells[1].subviews[0]; _statusSize = (UILabel *)cells[2].subviews[0]; _statusZoom = (UILabel *)cells[3].subviews[0];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    BOOL tools = _showTools && !_focusMode, colors = _showColors && !_focusMode, status = _showStatus && !_focusMode;
    _titleBar.frame = CGRectMake(0, 0, w, kTitleH);
    _appIcon.frame = CGRectMake(10, 7, 22, 22);
    CGFloat x = 38;
    for (XPFlatButton *b in @[_saveButton, _undoButton, _redoButton]) { b.frame = CGRectMake(x, 0, 44, kTitleH); x += 44; }
    CGFloat bx = w - 3 * 44 - 4;
    for (XPFlatButton *b in _windowButtons) { b.frame = CGRectMake(bx, 0, 44, kTitleH); bx += 44; }
    _titleLabel.frame = CGRectMake(x + 12, 0, w - 3 * 44 - x - 24, kTitleH);

    _menuBar.frame = CGRectMake(kBorder, kTitleH, w - kBorder * 2, kMenuH);
    CGFloat mx = 4;
    for (XPFlatButton *b in _menuButtons) {
        CGFloat bw = ceil([b.title sizeWithAttributes:@{NSFontAttributeName: XPFont(15)}].width) + 30;
        b.frame = CGRectMake(mx, 0, bw, kMenuH);
        mx += bw;
    }

    CGFloat statusH = status ? kStatusH : 0, colorH = colors ? kColorBoxH : 0, toolW = tools ? kToolboxW : 0;
    CGFloat bottom = h - kBorder - statusH, top = kTitleH + kMenuH;
    _statusBar.hidden = !status;
    _statusBar.frame = CGRectMake(kBorder, bottom, w - kBorder * 2, kStatusH);
    CGFloat sw = _statusBar.bounds.size.width, cellW[4] = {sw - 3 * 132 - 10, 132, 132, 132}, cx = 2;
    if (cellW[0] < 160) { cellW[1] = cellW[2] = cellW[3] = 104; cellW[0] = sw - 3 * 104 - 10; }
    for (NSUInteger i = 0; i < 4; i++) {
        _statusCells[i].frame = CGRectMake(cx, 3, cellW[i], kStatusH - 5);
        _statusCells[i].subviews[0].frame = CGRectMake(6, 0, cellW[i] - 10, kStatusH - 5);
        cx += cellW[i] + 2;
    }
    _colorBox.hidden = !colors;
    _colorBox.frame = CGRectMake(kBorder, bottom - kColorBoxH, w - kBorder * 2, kColorBoxH);
    bottom -= colorH;
    _toolbox.hidden = !tools;
    _toolbox.frame = CGRectMake(kBorder, top, kToolboxW, bottom - top);
    CGFloat bw = 46, bh = 44, ty = 6;
    for (NSUInteger i = 0; i < _toolButtons.count; i++) _toolButtons[i].frame = CGRectMake(6 + (i % 2) * (bw + 4), ty + (i / 2) * (bh + 2), bw, bh);
    CGFloat optionsY = ty + 8 * (bh + 2) + 6;
    _options.frame = CGRectMake(6, optionsY, kToolboxW - 12, MAX(0, _toolbox.bounds.size.height - optionsY - 6));

    CGRect old = _scroll.frame;
    _scroll.frame = CGRectMake(kBorder + toolW, top, w - kBorder * 2 - toolW, bottom - top);
    if (!CGSizeEqualToSize(old.size, _scroll.frame.size)) [self updateZoomLimitsFit:_fitZoom || CGRectIsEmpty(old)];
}

#pragma mark - Zoom and scrolling

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView { return _canvas; }
- (void)scrollViewDidZoom:(UIScrollView *)scrollView { [self centerCanvas]; [self zoomChanged]; }
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view { [_canvas cancelTouch]; _fitZoom = NO; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView { [_canvas cancelTouch]; }

- (void)resetCanvasFrame {
    _scroll.zoomScale = 1;
    _canvas.transform = CGAffineTransformIdentity;
    _canvas.frame = CGRectMake(0, 0, _canvas.bounds.size.width, _canvas.bounds.size.height);
    _canvas.layer.shadowPath = [UIBezierPath bezierPathWithRect:_canvas.bounds].CGPath;
    _scroll.contentSize = _canvas.frame.size;
}

- (CGFloat)fitScale {
    CGSize b = _scroll.bounds.size, c = _canvas.bounds.size;
    return MIN((b.width - 28) / c.width, (b.height - 28 - _keyboardInset) / c.height);
}

- (void)updateZoomLimitsFit:(BOOL)fit {
    if (_scroll.bounds.size.width < 1) return;
    CGFloat fitScale = [self fitScale];
    _scroll.minimumZoomScale = MIN(fitScale, 1);
    if (fit || _scroll.zoomScale < _scroll.minimumZoomScale) { _scroll.zoomScale = MIN(fitScale, 1); _fitZoom = YES; }
    [self centerCanvas];
    [self zoomChanged];
}

- (void)centerCanvas {
    CGSize b = _scroll.bounds.size, c = _scroll.contentSize;
    CGFloat ix = MAX(14, floor((b.width - c.width) / 2)), iy = MAX(14, floor((b.height - _keyboardInset - c.height) / 2));
    _scroll.contentInset = UIEdgeInsetsMake(iy, ix, iy + _keyboardInset, ix);
}

- (void)zoomChanged {
    _canvas.zoomScale = _scroll.zoomScale;
    _statusZoom.text = [NSString stringWithFormat:@"%d%%", (int)lround(_scroll.zoomScale * 100)];
}

- (void)zoomTo:(CGFloat)scale around:(CGPoint)point {
    _fitZoom = NO;
    CGSize b = _scroll.bounds.size;
    CGFloat z = MIN(MAX(scale, _scroll.minimumZoomScale), _scroll.maximumZoomScale);
    [_scroll zoomToRect:CGRectMake(point.x - b.width / z / 2, point.y - b.height / z / 2, b.width / z, b.height / z) animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (CGPoint)visibleCenter { CGRect r = [_scroll convertRect:_scroll.bounds toView:_canvas]; return CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)); }
- (void)zoomIn { [self zoomTo:_scroll.zoomScale * 2 around:[self visibleCenter]]; }
- (void)zoomOut { [self zoomTo:_scroll.zoomScale / 2 around:[self visibleCenter]]; }
- (void)zoomActual { [self zoomTo:1 around:[self visibleCenter]]; }
- (void)zoomToFit {
    _fitZoom = YES;
    CGFloat fit = [self fitScale];
    _scroll.minimumZoomScale = MIN(fit, 1);
    [_scroll setZoomScale:fit animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)keyboardWillChange:(NSNotification *)note {
    CGRect frame = [self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    _keyboardInset = MAX(0, CGRectGetMaxY(_scroll.frame) - frame.origin.y);
    [self centerCanvas];
    CGRect text = _canvas.activeTextRect;
    if (!CGRectIsNull(text)) [_scroll scrollRectToVisible:CGRectInset([_canvas convertRect:text toView:_scroll], -20, -20) animated:YES];
}
- (void)keyboardWillHide:(NSNotification *)note { _keyboardInset = 0; [self centerCanvas]; }

#pragma mark - Canvas delegate

- (void)canvasDidChange:(PaintCanvasView *)canvas {
    _undoButton.enabled = canvas.canUndo;
    _redoButton.enabled = canvas.canRedo;
    _needsAutosave = YES;
}

- (void)canvasDidResize:(PaintCanvasView *)canvas {
    [self resetCanvasFrame];
    [self updateZoomLimitsFit:YES];
    _statusSize.text = [NSString stringWithFormat:@"%d × %dpx", canvas.pixelWidth, canvas.pixelHeight];
}

- (void)canvas:(PaintCanvasView *)canvas didPickColor:(UIColor *)color {
    _primary = color;
    [self applySettings];
    [self selectTool:_toolBeforePicker];
}

- (void)canvas:(PaintCanvasView *)canvas didRequestZoomAtPoint:(CGPoint)point {
    CGFloat level = kZoomLevels[_zoomLevel];
    if (_scroll.zoomScale >= level * .99) [self zoomToFit]; else [self zoomTo:level around:point];
}

- (void)canvas:(PaintCanvasView *)canvas showStatus:(NSString *)status { _statusPos.text = status; }
- (CGRect)visibleRectForCanvas:(PaintCanvasView *)canvas { return [_scroll convertRect:_scroll.bounds toView:_canvas]; }

#pragma mark - Tools and options

- (void)toolTapped:(XPToolButton *)button { [self selectTool:(PaintTool)button.tag]; }

- (void)selectTool:(PaintTool)tool {
    if (tool == PaintToolPicker && _tool != PaintToolPicker) _toolBeforePicker = _tool;
    _tool = tool;
    _canvas.tool = tool;
    for (XPToolButton *b in _toolButtons) b.selected = b.tag == tool;
    _statusHint.text = @(kTools[tool].hint);
    _options.groups = [self optionGroupsForTool:tool];
    [self canvasDidChange:_canvas];
}

- (PaintOptionGroup *)sizeGroup:(const CGFloat *)sizes value:(NSInteger *)value label:(NSString *)label draw:(void (^)(CGFloat size, CGRect rect, UIColor *ink))draw {
    PaintOptionGroup *g = [PaintOptionGroup groupWithCount:4 columns:2];
    g.draw = ^(NSInteger i, CGRect r, UIColor *ink) { draw(sizes[i], r, ink); };
    g.isSelected = ^BOOL(NSInteger i) { return *value == i; };
    __weak PaintViewController *weakSelf = self;
    g.select = ^(NSInteger i) { *value = i; [weakSelf applySettings]; };
    g.label = ^NSString *(NSInteger i) { return [NSString stringWithFormat:@"%@ %g", label, sizes[i]]; };
    return g;
}

static void PaintDrawLine(CGFloat size, CGRect r, UIColor *ink) { [ink setFill]; CGFloat t = MIN(size, r.size.height - 4); UIRectFill(CGRectMake(r.origin.x + 4, round(CGRectGetMidY(r) - t / 2), r.size.width - 8, MAX(1, t))); }
static void PaintDrawSquare(CGFloat size, CGRect r, UIColor *ink) { [ink setFill]; CGFloat t = MIN(size * .8, r.size.height - 2); UIRectFill(CGRectMake(round(CGRectGetMidX(r) - t / 2), round(CGRectGetMidY(r) - t / 2), t, t)); }
static void PaintDrawDot(CGFloat size, CGRect r, UIColor *ink) { [ink setFill]; CGFloat t = MIN(size, r.size.height - 2); [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMidX(r) - t / 2, CGRectGetMidY(r) - t / 2, t, t)] fill]; }
static void PaintDrawText(NSString *text, UIFont *font, CGRect r, UIColor *ink) {
    NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: ink};
    CGSize s = [text sizeWithAttributes:attrs];
    [text drawAtPoint:CGPointMake(round(CGRectGetMidX(r) - s.width / 2), round(CGRectGetMidY(r) - s.height / 2)) withAttributes:attrs];
}

- (NSArray<PaintOptionGroup *> *)optionGroupsForTool:(PaintTool)tool {
    __weak PaintViewController *weakSelf = self;
    switch (tool) {
        case PaintToolFreeSelect: case PaintToolSelect: {
            PaintOptionGroup *g = [PaintOptionGroup groupWithCount:2 columns:1];
            g.draw = ^(NSInteger i, CGRect r, UIColor *ink) {
                CGRect box = CGRectInset(r, 10, 2);
                if (i == 0) { [UIColor.whiteColor setFill]; UIRectFill(box); }
                else for (int y = 0; y < 4; y++) for (int x = 0; x < 8; x++) { [((x + y) % 2 ? XPColor(0xC8C8C8) : UIColor.whiteColor) setFill]; UIRectFill(CGRectMake(box.origin.x + x * box.size.width / 8, box.origin.y + y * box.size.height / 4, ceil(box.size.width / 8), ceil(box.size.height / 4))); }
                [XPColor(0xD23B3B) setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(box.origin.x + 6, box.origin.y + 4, box.size.height - 8, box.size.height - 8)] fill];
                [XPColor(0x1F6FE0) setFill]; UIRectFill(CGRectMake(CGRectGetMaxX(box) - box.size.height - 2, box.origin.y + 5, box.size.height - 8, box.size.height - 10));
                [ink setStroke]; UIBezierPath *border = [UIBezierPath bezierPathWithRect:box]; [border stroke];
            };
            g.isSelected = ^BOOL(NSInteger i) { PaintViewController *s = weakSelf; return s && s->_transparentSelection == (i == 1); };
            g.select = ^(NSInteger i) { PaintViewController *s = weakSelf; if (s) { s->_transparentSelection = i == 1; [s applySettings]; } };
            g.label = ^NSString *(NSInteger i) { return i ? @"Transparent selection" : @"Opaque selection"; };
            return @[g];
        }
        case PaintToolEraser: return @[[self sizeGroup:kEraserSizes value:&_eraser label:@"Eraser size" draw:^(CGFloat size, CGRect r, UIColor *ink) { PaintDrawSquare(size, r, ink); }]];
        case PaintToolFill: {
            PaintOptionGroup *g = [PaintOptionGroup groupWithCount:4 columns:2];
            g.draw = ^(NSInteger i, CGRect r, UIColor *ink) { PaintDrawText(kToleranceNames[i], XPFont(12), r, ink); };
            g.isSelected = ^BOOL(NSInteger i) { PaintViewController *s = weakSelf; return s && s->_tolerance == i; };
            g.select = ^(NSInteger i) { PaintViewController *s = weakSelf; if (s) { s->_tolerance = i; [s applySettings]; } };
            g.label = ^NSString *(NSInteger i) { return [NSString stringWithFormat:@"Fill tolerance %@", kToleranceNames[i]]; };
            return @[g];
        }
        case PaintToolMagnifier: {
            PaintOptionGroup *g = [PaintOptionGroup groupWithCount:4 columns:2];
            g.draw = ^(NSInteger i, CGRect r, UIColor *ink) { PaintDrawText([NSString stringWithFormat:@"%g×", kZoomLevels[i]], XPBoldFont(14), r, ink); };
            g.isSelected = ^BOOL(NSInteger i) { PaintViewController *s = weakSelf; return s && s->_zoomLevel == i; };
            g.select = ^(NSInteger i) { PaintViewController *s = weakSelf; if (s) s->_zoomLevel = i; };
            g.label = ^NSString *(NSInteger i) { return [NSString stringWithFormat:@"Magnify %g times", kZoomLevels[i]]; };
            return @[g];
        }
        case PaintToolPencil: return @[[self sizeGroup:kPencilSizes value:&_pencil label:@"Pencil width" draw:^(CGFloat size, CGRect r, UIColor *ink) { PaintDrawLine(size, r, ink); }]];
        case PaintToolBrush: {
            PaintOptionGroup *shapes = [PaintOptionGroup groupWithCount:4 columns:2];
            shapes.draw = ^(NSInteger i, CGRect r, UIColor *ink) {
                CGFloat t = MIN(18, r.size.height - 4), cx = CGRectGetMidX(r), cy = CGRectGetMidY(r);
                [ink set];
                if (i == 0) [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx - t / 2, cy - t / 2, t, t)] fill];
                else if (i == 1) UIRectFill(CGRectMake(cx - t / 2, cy - t / 2, t, t));
                else {
                    UIBezierPath *p = [UIBezierPath bezierPath];
                    [p moveToPoint:CGPointMake(cx - t / 2, i == 2 ? cy + t / 2 : cy - t / 2)];
                    [p addLineToPoint:CGPointMake(cx + t / 2, i == 2 ? cy - t / 2 : cy + t / 2)];
                    p.lineWidth = 3; p.lineCapStyle = kCGLineCapRound; [p stroke];
                }
            };
            shapes.isSelected = ^BOOL(NSInteger i) { PaintViewController *s = weakSelf; return s && s->_brushShape == i; };
            shapes.select = ^(NSInteger i) { PaintViewController *s = weakSelf; if (s) { s->_brushShape = i; [s applySettings]; } };
            shapes.label = ^NSString *(NSInteger i) { return @[@"Round brush", @"Square brush", @"Forward slash brush", @"Back slash brush"][(NSUInteger)i]; };
            return @[shapes, [self sizeGroup:kBrushSizes value:&_brush label:@"Brush size" draw:^(CGFloat size, CGRect r, UIColor *ink) { PaintDrawDot(size, r, ink); }]];
        }
        case PaintToolAirbrush:
            return @[[self sizeGroup:kAirbrushSizes value:&_airbrush label:@"Airbrush size" draw:^(CGFloat size, CGRect r, UIColor *ink) {
                [ink setFill];
                CGFloat radius = MIN(size, r.size.height - 4) / 2;
                srand48((long)size);
                for (int i = 0; i < (int)(radius * 3); i++) {
                    CGFloat a = drand48() * 2 * M_PI, d = radius * sqrt(drand48());
                    UIRectFill(CGRectMake(round(CGRectGetMidX(r) + cos(a) * d), round(CGRectGetMidY(r) + sin(a) * d), 1, 1));
                }
            }]];
        case PaintToolText: {
            PaintOptionGroup *font = [PaintOptionGroup groupWithCount:1 columns:1];
            font.draw = ^(NSInteger i, CGRect r, UIColor *ink) {
                PaintViewController *s = weakSelf;
                if (!s) return;
                PaintFont f = PaintFontAt(s->_font);
                UIFont *preview = [UIFont fontWithName:s->_bold ? f.bold : f.regular size:13] ?: XPFont(13);
                [XPColor(0x716F64) setStroke]; [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(r, 0, 2) cornerRadius:3] stroke];
                PaintDrawText([f.name stringByAppendingString:@" ▾"], preview, r, UIColor.blackColor);
            };
            font.isSelected = ^BOOL(NSInteger i) { return NO; };
            font.select = ^(NSInteger i) { PaintViewController *s = weakSelf; if (s) { s->_font = (s->_font + 1) % kFontCount; [s applySettings]; } };
            font.label = ^NSString *(NSInteger i) { PaintViewController *s = weakSelf; return s ? [NSString stringWithFormat:@"Font: %@. Tap for the next font.", PaintFontAt(s->_font).name] : nil; };
            PaintOptionGroup *sizes = [self sizeGroup:kFontSizes value:&_fontSize label:@"Font size" draw:^(CGFloat size, CGRect r, UIColor *ink) { PaintDrawText(@"A", [UIFont fontWithName:@"TimesNewRomanPSMT" size:MIN(size * .8, r.size.height)], r, ink); }];
            PaintOptionGroup *toggles = [PaintOptionGroup groupWithCount:2 columns:2];
            toggles.draw = ^(NSInteger i, CGRect r, UIColor *ink) {
                if (i == 0) { PaintDrawText(@"B", [UIFont fontWithName:@"TimesNewRomanPS-BoldMT" size:18], r, ink); return; }
                CGRect box = CGRectInset(r, 7, 4);
                [ink setStroke]; [[UIBezierPath bezierPathWithRect:box] stroke];
                [ink setFill]; UIRectFill(CGRectInset(box, 3, 3));
            };
            toggles.isSelected = ^BOOL(NSInteger i) { PaintViewController *s = weakSelf; return s && (i == 0 ? s->_bold : s->_opaqueText); };
            toggles.select = ^(NSInteger i) { PaintViewController *s = weakSelf; if (!s) return; if (i == 0) s->_bold = !s->_bold; else s->_opaqueText = !s->_opaqueText; [s applySettings]; };
            toggles.label = ^NSString *(NSInteger i) { return i == 0 ? @"Bold" : @"Opaque background"; };
            return @[font, sizes, toggles];
        }
        case PaintToolLine: case PaintToolCurve:
            return @[[self sizeGroup:kLineSizes value:&_line label:@"Line width" draw:^(CGFloat size, CGRect r, UIColor *ink) { PaintDrawLine(size, r, ink); }]];
        case PaintToolRectangle: case PaintToolPolygon: case PaintToolEllipse: case PaintToolRoundedRect: {
            PaintOptionGroup *styles = [PaintOptionGroup groupWithCount:3 columns:1];
            styles.draw = ^(NSInteger i, CGRect r, UIColor *ink) {
                CGRect box = CGRectInset(r, 12, 3);
                if (i > 0) { [(i == 1 ? XPColor(0x9A9A9A) : ink) setFill]; UIRectFill(box); }
                if (i < 2) { [ink setStroke]; UIBezierPath *p = [UIBezierPath bezierPathWithRect:CGRectInset(box, .75, .75)]; p.lineWidth = 1.5; [p stroke]; }
            };
            styles.isSelected = ^BOOL(NSInteger i) { PaintViewController *s = weakSelf; return s && s->_fillStyle == i; };
            styles.select = ^(NSInteger i) { PaintViewController *s = weakSelf; if (s) { s->_fillStyle = i; [s applySettings]; } };
            styles.label = ^NSString *(NSInteger i) { return @[@"Outline", @"Outline with color 2 fill", @"Fill only"][(NSUInteger)i]; };
            return @[styles, [self sizeGroup:kLineSizes value:&_line label:@"Line width" draw:^(CGFloat size, CGRect r, UIColor *ink) { PaintDrawLine(size, r, ink); }]];
        }
        default: return @[];
    }
}

#pragma mark - Colors

- (void)pickSwatch:(NSUInteger)index secondary:(BOOL)secondary {
    _lastSwatch = index;
    if (secondary) _secondary = _palette[index]; else _primary = _palette[index];
    [self applySettings];
    _statusPos.text = secondary ? @"Color 2 set" : nil;
}

- (void)swapColors { UIColor *t = _primary; _primary = _secondary; _secondary = t; [self applySettings]; }

// As in XP, the edited color replaces the last palette swatch you picked.
- (void)editColors {
    [self prepareForModal];
    [PaintColorDialog showInView:self.view color:_primary completion:^(UIColor *color) {
        self->_primary = color;
        self->_palette[self->_lastSwatch] = color;
        [self applySettings];
        [self saveSettings];
    }];
}

- (void)resetPalette {
    for (NSUInteger i = 0; i < 28; i++) _palette[i] = XPColor(kDefaultPalette[i]);
    [self applySettings];
    [self saveSettings];
}

#pragma mark - Menus

- (void)menuTapped:(XPFlatButton *)button { if (_openMenuButton == button) [self closeMenu]; else [self openMenu:button]; }

- (void)openMenu:(XPFlatButton *)button {
    [self closeMenu];
    [_canvas cancelTouch];
    _menuCatcher = [[UIView alloc] initWithFrame:self.view.bounds];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(menuCatcherTapped:)];
    tap.delegate = self;
    [_menuCatcher addGestureRecognizer:tap];
    XPMenuView *menu = [[XPMenuView alloc] initWithItems:[self menuItems:button.tag]];
    CGRect b = [_menuBar convertRect:button.frame toView:self.view];
    menu.frame = CGRectMake(MIN(b.origin.x, self.view.bounds.size.width - menu.bounds.size.width - 6), CGRectGetMaxY(b) - 2, menu.bounds.size.width, menu.bounds.size.height);
    menu.onPick = ^(XPMenuItem *item) { [self closeMenu]; if (item.action) item.action(); };
    [_menuCatcher addSubview:menu];
    [self.view addSubview:_menuCatcher];
    button.lit = YES;
    _openMenuButton = button;
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, menu);
}

- (void)closeMenu {
    [_menuCatcher removeFromSuperview];
    _menuCatcher = nil;
    _openMenuButton.lit = NO;
    _openMenuButton = nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch { return touch.view == _menuCatcher; }

- (void)menuCatcherTapped:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:_menuBar];
    for (XPFlatButton *b in _menuButtons) if (CGRectContainsPoint(b.frame, p) && b != _openMenuButton) { [self openMenu:b]; return; }
    [self closeMenu];
}

- (NSArray<XPMenuItem *> *)menuItems:(NSInteger)menu {
    BOOL sel = _canvas.hasSelection;
    switch (menu) {
        case 0: return @[
            [XPMenuItem item:@"New" shortcut:@"Ctrl+N" action:^{ [self newPicture]; }],
            [XPMenuItem item:@"Open from Photos…" shortcut:@"Ctrl+O" action:^{ [self openFromPhotos]; }],
            [XPMenuItem item:@"Save to Photos" shortcut:@"Ctrl+S" action:^{ [self saveToPhotos]; }],
            [XPMenuItem separator],
            [XPMenuItem item:@"Send…" shortcut:nil action:^{ [self share]; }],
        ];
        case 1: return @[
            [XPMenuItem item:@"Undo" shortcut:@"Ctrl+Z" enabled:_canvas.canUndo checked:NO action:^{ [self undo]; }],
            [XPMenuItem item:@"Repeat" shortcut:@"Ctrl+Y" enabled:_canvas.canRedo checked:NO action:^{ [self redo]; }],
            [XPMenuItem separator],
            [XPMenuItem item:@"Cut" shortcut:@"Ctrl+X" enabled:sel checked:NO action:^{ [self->_canvas cutSelection]; }],
            [XPMenuItem item:@"Copy" shortcut:@"Ctrl+C" enabled:sel checked:NO action:^{ [self->_canvas copySelection]; }],
            [XPMenuItem item:@"Paste" shortcut:@"Ctrl+V" enabled:UIPasteboard.generalPasteboard.image != nil checked:NO action:^{ [self paste]; }],
            [XPMenuItem item:@"Clear Selection" shortcut:@"Del" enabled:sel checked:NO action:^{ [self->_canvas deleteSelection]; }],
            [XPMenuItem item:@"Select All" shortcut:@"Ctrl+A" action:^{ [self selectAll]; }],
        ];
        case 2: return @[
            [XPMenuItem item:@"Tool Box" shortcut:@"Ctrl+T" enabled:YES checked:_showTools action:^{ self->_showTools = !self->_showTools; [self panelsChanged]; }],
            [XPMenuItem item:@"Color Box" shortcut:@"Ctrl+L" enabled:YES checked:_showColors action:^{ self->_showColors = !self->_showColors; [self panelsChanged]; }],
            [XPMenuItem item:@"Status Bar" shortcut:nil enabled:YES checked:_showStatus action:^{ self->_showStatus = !self->_showStatus; [self panelsChanged]; }],
            [XPMenuItem separator],
            [XPMenuItem item:@"Zoom In" shortcut:@"Ctrl+PgUp" action:^{ [self zoomIn]; }],
            [XPMenuItem item:@"Zoom Out" shortcut:@"Ctrl+PgDn" action:^{ [self zoomOut]; }],
            [XPMenuItem item:@"Actual Pixels" shortcut:nil action:^{ [self zoomActual]; }],
            [XPMenuItem item:@"Fit to Window" shortcut:nil action:^{ [self zoomToFit]; }],
            [XPMenuItem separator],
            [XPMenuItem item:@"Hide Toolbars" shortcut:nil enabled:YES checked:_focusMode action:^{ [self toggleFocusMode]; }],
        ];
        case 3: return @[
            [XPMenuItem item:@"Flip Horizontal" shortcut:nil action:^{ [self->_canvas flipHorizontal]; }],
            [XPMenuItem item:@"Flip Vertical" shortcut:nil action:^{ [self->_canvas flipVertical]; }],
            [XPMenuItem item:@"Rotate Right 90°" shortcut:nil action:^{ [self->_canvas rotateQuarterTurns:1]; }],
            [XPMenuItem item:@"Rotate Left 90°" shortcut:nil action:^{ [self->_canvas rotateQuarterTurns:-1]; }],
            [XPMenuItem item:@"Rotate 180°" shortcut:nil action:^{ [self->_canvas rotateQuarterTurns:2]; }],
            [XPMenuItem separator],
            [XPMenuItem item:@"Invert Colors" shortcut:@"Ctrl+I" action:^{ [self->_canvas invertColors]; }],
            [XPMenuItem item:@"Attributes…" shortcut:@"Ctrl+E" action:^{ [self showAttributes]; }],
            [XPMenuItem item:sel ? @"Clear Selection" : @"Clear Image" shortcut:@"Ctrl+Shft+N" action:^{ [self->_canvas clearImage]; }],
            [XPMenuItem item:@"Draw Opaque" shortcut:nil enabled:YES checked:!_transparentSelection action:^{ self->_transparentSelection = !self->_transparentSelection; [self applySettings]; }],
        ];
        case 4: return @[
            [XPMenuItem item:@"Edit Colors…" shortcut:nil action:^{ [self editColors]; }],
            [XPMenuItem item:@"Swap Colors" shortcut:nil action:^{ [self swapColors]; }],
            [XPMenuItem item:@"Reset Palette" shortcut:nil action:^{ [self resetPalette]; }],
        ];
        default: return @[
            [XPMenuItem item:@"Paint Tips" shortcut:nil action:^{ [self showTips]; }],
            [XPMenuItem separator],
            [XPMenuItem item:@"About Paint" shortcut:nil action:^{ [self showAbout]; }],
        ];
    }
}

- (void)panelsChanged {
    [self saveSettings];
    [self.view setNeedsLayout];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : .2 animations:^{ [self.view layoutIfNeeded]; }];
}

- (void)toggleFocusMode { _focusMode = !_focusMode; [self panelsChanged]; }

#pragma mark - Commands

- (void)prepareForModal { [_canvas cancelTouch]; [self closeMenu]; }
- (void)undo { [_canvas undo]; }
- (void)redo { [_canvas redo]; }
- (void)selectAll { [self selectTool:PaintToolSelect]; [_canvas selectAll]; }

- (void)paste {
    UIImage *image = UIPasteboard.generalPasteboard.image;
    if (!image) { [self showMessage:@"There is nothing on the Clipboard to paste." title:@"Paint" icon:XPDialogIconInfo]; return; }
    if (_tool != PaintToolSelect && _tool != PaintToolFreeSelect) [self selectTool:PaintToolSelect];
    [_canvas pasteImage:image];
}

- (void)showMessage:(NSString *)message title:(NSString *)title icon:(XPDialogIcon)icon {
    [self prepareForModal];
    [XPDialog showInView:self.view title:title message:message icon:icon buttons:@[@"OK"] handler:nil];
}

// Mirrors XP's "Save changes to untitled?" before anything replaces the picture.
- (void)confirmDiscard:(void (^)(void))then {
    [self prepareForModal];
    [_canvas commitPending];
    if (!_canvas.hasChanges) { then(); return; }
    [XPDialog showInView:self.view title:@"Paint" message:@"Save changes to untitled?" icon:XPDialogIconWarning buttons:@[@"Yes", @"No", @"Cancel"] handler:^(NSInteger index) {
        if (index == 0) [self saveImageThen:then];
        else if (index == 1) then();
    }];
}

- (void)newPicture {
    [self confirmDiscard:^{
        CGSize size = [self defaultCanvasSizeForSize:self.view.bounds.size];
        [self->_canvas resetWithPixelWidth:(int)size.width height:(int)size.height image:nil];
        self->_needsAutosave = YES;
    }];
}

- (void)saveToPhotos { [self prepareForModal]; [self saveImageThen:nil]; }

- (void)saveImageThen:(void (^)(void))then {
    UIImage *image = [UIImage imageWithData:UIImagePNGRepresentation([_canvas snapshotImage])];
    _afterSave = then;
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)info {
    void (^then)(void) = _afterSave;
    _afterSave = nil;
    if (error) {
        [self showMessage:@"Paint couldn't save to Photos. Check that Paint is allowed to use Photos in Settings > Privacy > Photos." title:@"Paint" icon:XPDialogIconWarning];
        return;
    }
    [_canvas markSaved];
    if (then) then(); else [self showMessage:@"Your picture was saved to Photos." title:@"Paint" icon:XPDialogIconInfo];
}

- (void)openFromPhotos {
    [self confirmDiscard:^{
        if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
        UIImagePickerController *picker = [UIImagePickerController new];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.delegate = self;
        picker.modalPresentationStyle = UIModalPresentationPopover;
        picker.popoverPresentationController.sourceView = self->_menuBar;
        picker.popoverPresentationController.sourceRect = self->_menuButtons[0].frame;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!image) return;
    CGSize size = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
    CGFloat fit = MIN(1, kMaxImageSide / MAX(size.width, size.height));
    [_canvas resetWithPixelWidth:MAX(1, (int)round(size.width * fit)) height:MAX(1, (int)round(size.height * fit)) image:image];
    _needsAutosave = YES;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }

- (void)share {
    [self prepareForModal];
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[_canvas snapshotImage]] applicationActivities:nil];
    share.modalPresentationStyle = UIModalPresentationPopover;
    share.popoverPresentationController.sourceView = _menuBar;
    share.popoverPresentationController.sourceRect = _menuButtons[0].frame;
    [self presentViewController:share animated:YES completion:nil];
}

- (void)showAttributes {
    [self prepareForModal];
    NSString *message = [NSString stringWithFormat:@"The picture is %d × %d pixels. Pick a new size; the picture stays anchored at the top-left corner.", _canvas.pixelWidth, _canvas.pixelHeight];
    [XPDialog showInView:self.view title:@"Attributes" message:message icon:XPDialogIconNone buttons:@[@"Landscape", @"Portrait", @"Square", @"Cancel"] handler:^(NSInteger index) {
        CGSize sizes[3] = {CGSizeMake(1760, 1120), CGSizeMake(1120, 1760), CGSizeMake(1440, 1440)};
        if (index < 3) [self->_canvas resizeCanvasToWidth:(int)sizes[index].width height:(int)sizes[index].height];
    }];
}

- (void)showTips {
    [self showMessage:@"• Draw with one finger. Pinch to zoom; drag with two fingers to scroll.\n• Tap with two fingers to undo, three fingers to redo.\n• Tap a color for color 1; touch and hold for color 2. Tap the color well to swap them.\n• Shapes outline in color 1 and fill with color 2.\n• Pick Color returns to your last tool after one tap.\n• Your picture is kept when you leave the app." title:@"Paint Tips" icon:XPDialogIconInfo];
}

- (void)showAbout {
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [self showMessage:[NSString stringWithFormat:@"Paint for iPad\nVersion %@\n\nA tribute to Paint for Windows XP, made for the iPad mini. Fully offline.", version] title:@"About Paint" icon:XPDialogIconInfo];
}

#pragma mark - Hardware keyboard

- (BOOL)canBecomeFirstResponder { return YES; }
- (NSArray<UIKeyCommand *> *)keyCommands {
    UIKeyModifierFlags cmd = UIKeyModifierCommand;
    return @[[UIKeyCommand keyCommandWithInput:@"z" modifierFlags:cmd action:@selector(undo)],
             [UIKeyCommand keyCommandWithInput:@"z" modifierFlags:cmd | UIKeyModifierShift action:@selector(redo)],
             [UIKeyCommand keyCommandWithInput:@"s" modifierFlags:cmd action:@selector(saveToPhotos)]];
}
@end
