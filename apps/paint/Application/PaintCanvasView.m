#import "PaintCanvasView.h"
#import "Model/PaintHistory.h"
#import "XPChrome.h"
#import <QuartzCore/QuartzCore.h>

static const NSUInteger PaintHistoryBytes = 72 * 1024 * 1024;

typedef NS_ENUM(NSInteger, PaintSelectionDrag) { PaintSelectionDragNone, PaintSelectionDragCreate, PaintSelectionDragMove, PaintSelectionDragResize };
typedef NS_ENUM(NSInteger, PaintTransform) { PaintTransformFlipH, PaintTransformFlipV, PaintTransformRotateCW, PaintTransformRotateCCW, PaintTransformRotate180, PaintTransformInvert };

static uint32_t PaintPackColor(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 1, w = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a] && [color getWhite:&w alpha:&a]) r = g = b = w;
    return PaintPackRGBA((uint8_t)lround(r * a * 255), (uint8_t)lround(g * a * 255), (uint8_t)lround(b * a * 255), (uint8_t)lround(a * 255));
}

// Contexts are flipped so drawing uses UIKit coordinates (origin top-left, y down), matching buffer rows.
static CGContextRef PaintCreateContext(int w, int h, void *data) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(data, w, h, 8, (size_t)w * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(c, 0, h);
    CGContextScaleCTM(c, 1, -1);
    return c;
}

static CGImageRef PaintCreateImage(NSData *data, int w, int h, BOOL opaque) {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(w, h, 8, 32, (size_t)w * 4, space, (opaque ? kCGImageAlphaNoneSkipLast : kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    return image;
}

static NSMutableData *PaintPixelsOfImage(CGImageRef image) {
    int w = (int)CGImageGetWidth(image), h = (int)CGImageGetHeight(image);
    NSMutableData *data = [NSMutableData dataWithLength:(size_t)w * h * 4];
    CGContextRef c = PaintCreateContext(w, h, data.mutableBytes);
    CGContextScaleCTM(c, 1, -1);
    CGContextTranslateCTM(c, 0, -h);
    CGContextDrawImage(c, CGRectMake(0, 0, w, h), image);
    CGContextRelease(c);
    return data;
}

static CGFloat PaintDistance(CGPoint a, CGPoint b) { return hypot(a.x - b.x, a.y - b.y); }

@implementation PaintCanvasView {
    int _w, _h;
    uint32_t *_pixels, *_snapshot;
    CGContextRef _ctx;
    CGColorSpaceRef _space;
    PaintHistory *_history;
    BOOL _opOpen;
    PaintIRect _opDirty;
    NSUInteger _generation, _savedGeneration;

    UITouch *_touch;
    CGPoint _start, _last, _lastMid;
    CAShapeLayer *_preview;
    CADisplayLink *_sprayLink;

    NSInteger _curveStage;
    CGPoint _curveA, _curveB, _curveC1, _curveC2, _curveSavedC1, _curveSavedC2;
    NSMutableArray<NSValue *> *_polygon;
    BOOL _polygonDragging;
    CGPoint _polygonLive;

    CGImageRef _selOpaque, _selImage;
    CGRect _selFrame, _selDragStart;
    CGSize _selNaturalSize;
    UIBezierPath *_selOutline;
    PaintSelectionDrag _selDrag;
    CGPoint _dragAnchor;
    NSMutableArray<NSValue *> *_lasso;
    CALayer *_selLayer, *_handle;
    CAShapeLayer *_antsLight, *_antsDark;
    CGFloat _antsZoom;

    UITextView *_textView;
}

- (instancetype)initWithPixelWidth:(int)width height:(int)height scale:(CGFloat)scale {
    if ((self = [super initWithFrame:CGRectMake(0, 0, width / scale, height / scale)])) {
        _pixelScale = scale;
        _zoomScale = 1;
        _space = CGColorSpaceCreateDeviceRGB();
        _history = [[PaintHistory alloc] initWithByteLimit:PaintHistoryBytes maxSteps:80];
        _primaryColor = UIColor.blackColor;
        _secondaryColor = UIColor.whiteColor;
        _pencilWidth = scale; _lineWidth = 2 * scale; _brushSize = 6 * scale; _eraserSize = 12 * scale; _airbrushSize = 24 * scale; _fontSize = 24 * scale;
        _fontName = @"ArialMT";
        _fillTolerance = 32;
        _polygon = [NSMutableArray array];
        self.opaque = YES;
        self.backgroundColor = UIColor.whiteColor;
        self.multipleTouchEnabled = YES;
        self.layer.magnificationFilter = kCAFilterNearest;
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"Canvas";
        self.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
        [self replaceBufferWidth:width height:height pixels:NULL];
    }
    return self;
}

- (void)dealloc {
    [_sprayLink invalidate];
    CGContextRelease(_ctx);
    CGColorSpaceRelease(_space);
    CGImageRelease(_selOpaque);
    CGImageRelease(_selImage);
    free(_pixels);
    free(_snapshot);
}

- (int)pixelWidth { return _w; }
- (int)pixelHeight { return _h; }
- (BOOL)hasSelection { return _selImage != NULL; }
- (BOOL)hasChanges { return _generation != _savedGeneration; }
- (BOOL)hasPendingInteraction { return _selImage || _textView || _curveStage > 0 || _polygon.count > 0; }
- (BOOL)canUndo { return _history.canUndo || [self hasPendingInteraction]; }
- (BOOL)canRedo { return _history.canRedo; }
- (void)markSaved { _savedGeneration = _generation; }
- (void)markUnsaved { _savedGeneration = _generation - 1; }
- (CGRect)activeTextRect { return _textView ? _textView.frame : CGRectNull; }

#pragma mark - Buffer

// Takes ownership of pixels; NULL means a fresh white canvas.
- (void)replaceBufferWidth:(int)w height:(int)h pixels:(uint32_t *)pixels {
    CGContextRelease(_ctx);
    free(_pixels);
    free(_snapshot);
    _w = w; _h = h;
    _pixels = pixels;
    if (!_pixels) { _pixels = malloc((size_t)w * h * 4); memset(_pixels, 0xff, (size_t)w * h * 4); }
    _snapshot = malloc((size_t)w * h * 4);
    _ctx = PaintCreateContext(w, h, _pixels);
    _opOpen = NO;
    self.bounds = CGRectMake(0, 0, w / _pixelScale, h / _pixelScale);
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat s = _pixelScale;
    int x0 = MAX(0, (int)floor(rect.origin.x * s)), y0 = MAX(0, (int)floor(rect.origin.y * s));
    int x1 = MIN(_w, (int)ceil(CGRectGetMaxX(rect) * s)), y1 = MIN(_h, (int)ceil(CGRectGetMaxY(rect) * s));
    if (x1 <= x0 || y1 <= y0) return;
    // Wrap just the dirty rows in a throwaway image; nothing is copied until it is drawn.
    size_t stride = (size_t)_w * 4, length = (size_t)(y1 - y0 - 1) * stride + (size_t)(x1 - x0) * 4;
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, _pixels + (size_t)y0 * _w + x0, length, NULL);
    CGImageRef image = CGImageCreate(x1 - x0, y1 - y0, 8, 32, stride, _space, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect dest = CGRectMake(x0 / s, y0 / s, (x1 - x0) / s, (y1 - y0) / s);
    CGContextSaveGState(c);
    CGContextSetInterpolationQuality(c, kCGInterpolationNone);
    CGContextTranslateCTM(c, 0, CGRectGetMinY(dest) + CGRectGetMaxY(dest));
    CGContextScaleCTM(c, 1, -1);
    CGContextDrawImage(c, dest, image);
    CGContextRestoreGState(c);
    CGImageRelease(image);
    CGDataProviderRelease(provider);
}

- (CGPoint)pixelPointOf:(UITouch *)touch { CGPoint p = [touch locationInView:self]; return CGPointMake(p.x * _pixelScale, p.y * _pixelScale); }
- (CGRect)pointRect:(CGRect)r { CGFloat s = _pixelScale; return CGRectMake(r.origin.x / s, r.origin.y / s, r.size.width / s, r.size.height / s); }
- (PaintIRect)clampedIRect:(CGRect)r {
    if (CGRectIsNull(r)) return PaintIRectMake(0, 0, 0, 0);
    CGRect i = CGRectIntegral(r);
    return PaintIRectIntersect(PaintIRectMake((int)i.origin.x, (int)i.origin.y, (int)i.size.width, (int)i.size.height), PaintIRectMake(0, 0, _w, _h));
}
- (void)invalidatePixels:(PaintIRect)r { if (!PaintIRectIsEmpty(r)) [self setNeedsDisplayInRect:[self pointRect:CGRectMake(r.x, r.y, r.w, r.h)]]; }

#pragma mark - Operations and history

// An operation snapshots the canvas, tracks what it touches, and records only that rect for undo.
- (void)beginOp {
    if (_opOpen) return;
    memcpy(_snapshot, _pixels, (size_t)_w * _h * 4);
    _opOpen = YES;
    _opDirty = PaintIRectMake(0, 0, 0, 0);
}
- (void)dirtyPixels:(CGRect)r {
    PaintIRect ir = [self clampedIRect:r];
    if (PaintIRectIsEmpty(ir)) return;
    _opDirty = PaintIRectUnion(_opDirty, ir);
    [self invalidatePixels:ir];
}
- (void)endOp {
    if (!_opOpen) return;
    _opOpen = NO;
    if (PaintIRectIsEmpty(_opDirty)) { [self.delegate canvasDidChange:self]; return; }
    NSMutableData *data = [NSMutableData dataWithLength:(size_t)_opDirty.w * _opDirty.h * 4];
    PaintCopyRect(_snapshot, _w, _opDirty, data.mutableBytes);
    [_history recordChange:[PaintPatch patchWithRect:_opDirty canvasWidth:_w height:_h pixels:data whole:NO]];
    [self changed];
}
- (void)cancelOp {
    if (!_opOpen) return;
    _opOpen = NO;
    PaintIRect r = _opDirty;
    if (PaintIRectIsEmpty(r)) return;
    for (int y = r.y; y < r.y + r.h; y++) memcpy(_pixels + (size_t)y * _w + r.x, _snapshot + (size_t)y * _w + r.x, (size_t)r.w * 4);
    [self invalidatePixels:r];
}
- (void)changed { _generation++; [self.delegate canvasDidChange:self]; }
- (PaintPatch *)wholePatch { return [PaintPatch patchWithRect:PaintIRectMake(0, 0, _w, _h) canvasWidth:_w height:_h pixels:[NSData dataWithBytes:_pixels length:(size_t)_w * _h * 4] whole:YES]; }

- (PaintPatch *)inverseOf:(PaintPatch *)patch {
    if (patch.whole) return [self wholePatch];
    NSMutableData *data = [NSMutableData dataWithLength:patch.pixels.length];
    PaintCopyRect(_pixels, _w, patch.rect, data.mutableBytes);
    return [PaintPatch patchWithRect:patch.rect canvasWidth:_w height:_h pixels:data whole:NO];
}

- (void)applyPatch:(PaintPatch *)patch {
    if (!patch.whole) { PaintPasteRect(_pixels, _w, patch.rect, patch.pixels.bytes); [self invalidatePixels:patch.rect]; return; }
    if (patch.canvasWidth == _w && patch.canvasHeight == _h) { memcpy(_pixels, patch.pixels.bytes, patch.pixels.length); [self setNeedsDisplay]; return; }
    uint32_t *pixels = malloc(patch.pixels.length);
    memcpy(pixels, patch.pixels.bytes, patch.pixels.length);
    [self replaceBufferWidth:patch.canvasWidth height:patch.canvasHeight pixels:pixels];
    [self.delegate canvasDidResize:self];
}

- (void)undo {
    [self cancelTouch];
    // Like XP, undo first abandons whatever is still floating or half drawn.
    if ([self cancelPending]) { [self.delegate canvasDidChange:self]; return; }
    PaintPatch *patch = [_history takeUndo];
    if (!patch) return;
    [_history pushRedo:[self inverseOf:patch]];
    [self applyPatch:patch];
    [self changed];
}

- (void)redo {
    [self cancelTouch];
    [self cancelPending];
    PaintPatch *patch = [_history takeRedo];
    if (!patch) return;
    [_history pushUndo:[self inverseOf:patch]];
    [self applyPatch:patch];
    [self changed];
}

- (BOOL)cancelPending {
    BOOL any = [self hasPendingInteraction];
    if (_textView) [self removeTextView];
    if (_selImage) { [self dropSelection]; [self cancelOp]; }
    _curveStage = 0;
    [_polygon removeAllObjects];
    [self clearPreview];
    return any;
}

- (void)commitPending {
    [self commitText];
    [self commitSelection];
    [self commitCurve];
    [self commitPolygon];
}

- (void)resetWithPixelWidth:(int)width height:(int)height image:(UIImage *)image {
    [self cancelTouch];
    [self cancelPending];
    [_history removeAll];
    [self replaceBufferWidth:width height:height pixels:NULL];
    if (image) { UIGraphicsPushContext(_ctx); [image drawInRect:CGRectMake(0, 0, width, height)]; UIGraphicsPopContext(); }
    _generation = _savedGeneration = 0;
    [self.delegate canvasDidResize:self];
    [self.delegate canvasDidChange:self];
}

- (void)resizeCanvasToWidth:(int)width height:(int)height {
    [self cancelTouch];
    [self commitPending];
    if (width == _w && height == _h) return;
    [_history recordChange:[self wholePatch]];
    uint32_t fill = PaintPackColor(_secondaryColor), *pixels = malloc((size_t)width * height * 4);
    for (size_t i = 0; i < (size_t)width * height; i++) pixels[i] = fill;
    int cw = MIN(width, _w), ch = MIN(height, _h);
    for (int y = 0; y < ch; y++) memcpy(pixels + (size_t)y * width, _pixels + (size_t)y * _w, (size_t)cw * 4);
    [self replaceBufferWidth:width height:height pixels:pixels];
    [self changed];
    [self.delegate canvasDidResize:self];
}

- (UIImage *)snapshotImage {
    [self commitPending];
    CGImageRef image = PaintCreateImage([NSData dataWithBytes:_pixels length:(size_t)_w * _h * 4], _w, _h, YES);
    UIImage *result = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    return result;
}

#pragma mark - Settings

- (void)setTool:(PaintTool)tool {
    if (tool == _tool) return;
    [self cancelTouch];
    [self commitPending];
    _tool = tool;
}
- (void)setPrimaryColor:(UIColor *)color { _primaryColor = color; [self styleTextView]; }
- (void)setSecondaryColor:(UIColor *)color { _secondaryColor = color; [self styleTextView]; [self rebuildSelectionImage]; }
- (void)setFontSize:(CGFloat)size { _fontSize = size; [self styleTextView]; }
- (void)setFontName:(NSString *)name { _fontName = [name copy]; [self styleTextView]; }
- (void)setOpaqueText:(BOOL)opaque { _opaqueText = opaque; [self styleTextView]; }
- (void)setTransparentSelection:(BOOL)transparent { _transparentSelection = transparent; [self rebuildSelectionImage]; }
- (void)setZoomScale:(CGFloat)zoom {
    _zoomScale = zoom;
    _textView.layer.borderWidth = 1 / zoom;
    [self layoutSelection];
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // A second finger means pinch or scroll: abandon the stroke and let the scroll view have it.
    if (_touch || event.allTouches.count > 1) { [self cancelTouch]; return; }
    _touch = touches.anyObject;
    [self beginAt:[self pixelPointOf:_touch]];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_touch || ![touches containsObject:_touch]) return;
    NSArray<UITouch *> *samples = [event coalescedTouchesForTouch:_touch] ?: @[_touch];
    for (UITouch *sample in samples) [self moveTo:[self pixelPointOf:sample]];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_touch || ![touches containsObject:_touch]) return;
    CGPoint p = [self pixelPointOf:_touch];
    _touch = nil;
    [self endAt:p];
    [self.delegate canvas:self showStatus:nil];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_touch && [touches containsObject:_touch]) [self cancelTouch];
}

- (void)cancelTouch {
    if (!_touch) return;
    _touch = nil;
    [self stopSpray];
    switch (_tool) {
        case PaintToolFreeSelect:
        case PaintToolSelect:
            if (_selDrag == PaintSelectionDragCreate) [self clearPreview];
            else if (_selDrag != PaintSelectionDragNone) { _selFrame = _selDragStart; [self layoutSelection]; }
            _selDrag = PaintSelectionDragNone;
            break;
        case PaintToolPencil: case PaintToolBrush: case PaintToolEraser: case PaintToolAirbrush:
            [self cancelOp];
            break;
        case PaintToolCurve:
            if (_curveStage == 0) [self clearPreview];
            else { _curveC1 = _curveSavedC1; _curveC2 = _curveSavedC2; [self updateCurvePreview]; }
            break;
        case PaintToolPolygon:
            if (_polygonDragging) { [_polygon removeAllObjects]; [self clearPreview]; } else [self updatePolygonPreview];
            break;
        default:
            [self clearPreview];
            break;
    }
    [self.delegate canvas:self showStatus:nil];
}

- (void)beginAt:(CGPoint)p {
    _start = _last = _lastMid = p;
    switch (_tool) {
        case PaintToolFreeSelect: case PaintToolSelect: [self beginSelectionAt:p]; break;
        case PaintToolPencil: case PaintToolBrush: case PaintToolEraser: [self beginOp]; [self strokeTo:p first:YES]; break;
        case PaintToolAirbrush:
            [self beginOp];
            [self spray];
            _sprayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(spray)];
            [_sprayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
            break;
        case PaintToolText:
            // A tap outside the text box only commits it, as in XP.
            if (_textView) { [self commitText]; _touch = nil; return; }
            break;
        case PaintToolCurve:
            _curveSavedC1 = _curveC1; _curveSavedC2 = _curveC2;
            if (_curveStage == 0) _curveA = _curveB = p;
            else if (_curveStage == 1) _curveC1 = _curveC2 = p;
            else _curveC2 = p;
            [self updateCurvePreview];
            break;
        case PaintToolPolygon:
            _polygonDragging = _polygon.count == 0;
            if (_polygonDragging) [_polygon addObject:[NSValue valueWithCGPoint:p]];
            _polygonLive = p;
            [self updatePolygonPreview];
            break;
        case PaintToolLine: case PaintToolRectangle: case PaintToolEllipse: case PaintToolRoundedRect: [self updateShapePreviewTo:p]; break;
        default: break;
    }
    [self reportPoint:p];
}

- (void)moveTo:(CGPoint)p {
    switch (_tool) {
        case PaintToolFreeSelect: case PaintToolSelect: [self moveSelectionTo:p]; break;
        case PaintToolPencil: case PaintToolBrush: case PaintToolEraser: [self strokeTo:p first:NO]; break;
        case PaintToolAirbrush: _last = p; break;
        case PaintToolText:
            _last = p;
            [self showPreviewPath:[UIBezierPath bezierPathWithRect:CGRectStandardize(CGRectMake(_start.x, _start.y, p.x - _start.x, p.y - _start.y))] stroke:UIColor.blackColor fill:nil width:0 dashed:YES];
            break;
        case PaintToolCurve:
            if (_curveStage == 0) _curveB = p; else if (_curveStage == 1) _curveC1 = _curveC2 = p; else _curveC2 = p;
            [self updateCurvePreview];
            break;
        case PaintToolPolygon: _polygonLive = p; [self updatePolygonPreview]; break;
        case PaintToolLine: case PaintToolRectangle: case PaintToolEllipse: case PaintToolRoundedRect: [self updateShapePreviewTo:p]; break;
        default: break;
    }
    if (_tool != PaintToolSelect && _tool != PaintToolFreeSelect) [self reportPoint:p];
}

- (void)endAt:(CGPoint)p {
    switch (_tool) {
        case PaintToolFreeSelect: case PaintToolSelect: [self endSelectionAt:p]; break;
        case PaintToolPencil: case PaintToolBrush: case PaintToolEraser:
            [self strokeTo:p first:NO];
            [self finishStroke];
            [self endOp];
            break;
        case PaintToolAirbrush: [self stopSpray]; [self endOp]; break;
        case PaintToolFill: [self floodAt:p]; break;
        case PaintToolPicker: if ([self containsPixel:p]) [self.delegate canvas:self didPickColor:[self colorAt:p]]; break;
        case PaintToolMagnifier: [self.delegate canvas:self didRequestZoomAtPoint:CGPointMake(p.x / _pixelScale, p.y / _pixelScale)]; break;
        case PaintToolText: [self clearPreview]; [self beginTextFrom:_start to:p]; break;
        case PaintToolCurve:
            if (_curveStage == 0) {
                if (PaintDistance(_curveA, _curveB) < 2 * _pixelScale) { [self clearPreview]; break; }
                _curveC1 = _curveA; _curveC2 = _curveB; _curveStage = 1;
            } else if (_curveStage == 1) {
                _curveStage = 2;
            } else {
                [self commitCurve];
            }
            [self.delegate canvasDidChange:self];
            break;
        case PaintToolPolygon: [self endPolygonAt:p]; break;
        case PaintToolLine: case PaintToolRectangle: case PaintToolEllipse: case PaintToolRoundedRect:
            [self clearPreview];
            if (_tool == PaintToolLine || PaintDistance(_start, p) >= 1) [self drawShape:[self shapePathFrom:_start to:p] fillable:_tool != PaintToolLine];
            break;
        default: break;
    }
}

- (void)reportPoint:(CGPoint)p {
    if (![self containsPixel:p]) { [self.delegate canvas:self showStatus:nil]; return; }
    [self.delegate canvas:self showStatus:[NSString stringWithFormat:@"%d, %dpx", (int)p.x, (int)p.y]];
}

- (BOOL)containsPixel:(CGPoint)p { return p.x >= 0 && p.y >= 0 && p.x < _w && p.y < _h; }

- (UIColor *)colorAt:(CGPoint)p {
    uint8_t r, g, b, a;
    PaintUnpackRGBA(_pixels[(size_t)(int)p.y * _w + (int)p.x], &r, &g, &b, &a);
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1];
}

#pragma mark - Preview

- (void)clearPreview { [_preview removeFromSuperlayer]; _preview = nil; }

- (void)showPreviewPath:(UIBezierPath *)pixelPath stroke:(UIColor *)stroke fill:(UIColor *)fill width:(CGFloat)width dashed:(BOOL)dashed {
    UIBezierPath *path = [pixelPath copy];
    [path applyTransform:CGAffineTransformMakeScale(1 / _pixelScale, 1 / _pixelScale)];
    if (!_preview) {
        _preview = [CAShapeLayer layer];
        _preview.lineCap = kCALineCapRound;
        _preview.lineJoin = kCALineJoinRound;
        [self.layer addSublayer:_preview];
    }
    CAShapeLayer *layer = _preview;
    CGFloat z = _zoomScale, s = _pixelScale;
    XPNoAnimation(^{
        layer.frame = self.bounds;
        layer.path = path.CGPath;
        layer.strokeColor = stroke.CGColor;
        layer.fillColor = fill.CGColor;
        layer.lineWidth = dashed ? 1 / z : width / s;
        layer.lineDashPattern = dashed ? @[@(4 / z), @(3 / z)] : nil;
    });
}

- (UIBezierPath *)shapePathFrom:(CGPoint)a to:(CGPoint)b {
    if (_tool == PaintToolLine) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:a];
        [path addLineToPoint:b];
        return path;
    }
    CGRect r = CGRectStandardize(CGRectMake(a.x, a.y, b.x - a.x, b.y - a.y));
    if (_tool == PaintToolEllipse) return [UIBezierPath bezierPathWithOvalInRect:r];
    if (_tool == PaintToolRoundedRect) return [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:MIN(MIN(r.size.width, r.size.height) / 2, 12 * _pixelScale)];
    return [UIBezierPath bezierPathWithRect:r];
}

- (void)updateShapePreviewTo:(CGPoint)p {
    BOOL fillable = _tool != PaintToolLine;
    UIColor *fill = fillable && _fillStyle != PaintFillOutline ? (_fillStyle == PaintFillSolid ? _primaryColor : _secondaryColor) : nil;
    UIColor *stroke = !fillable || _fillStyle != PaintFillSolid ? _primaryColor : UIColor.clearColor;
    [self showPreviewPath:[self shapePathFrom:_start to:p] stroke:stroke fill:fill width:_lineWidth dashed:NO];
}

// Outline in the primary color, fill in the secondary (or primary for fill-only), as in XP.
- (void)drawShape:(UIBezierPath *)path fillable:(BOOL)fillable {
    [self beginOp];
    CGContextRef c = _ctx;
    CGContextSaveGState(c);
    CGContextSetShouldAntialias(c, YES);
    if (fillable && _fillStyle != PaintFillOutline) {
        CGContextSetFillColorWithColor(c, (_fillStyle == PaintFillSolid ? _primaryColor : _secondaryColor).CGColor);
        CGContextAddPath(c, path.CGPath);
        CGContextFillPath(c);
    }
    if (!fillable || _fillStyle != PaintFillSolid) {
        CGContextSetStrokeColorWithColor(c, _primaryColor.CGColor);
        CGContextSetLineWidth(c, _lineWidth);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGContextSetLineJoin(c, _tool == PaintToolRectangle ? kCGLineJoinMiter : kCGLineJoinRound);
        CGContextAddPath(c, path.CGPath);
        CGContextStrokePath(c);
    }
    CGContextRestoreGState(c);
    [self dirtyPixels:CGRectInset(CGPathGetPathBoundingBox(path.CGPath), -_lineWidth - 2, -_lineWidth - 2)];
    [self endOp];
}

#pragma mark - Freehand

- (void)strokeTo:(CGPoint)p first:(BOOL)first {
    if (!first && CGPointEqualToPoint(p, _last)) return;
    CGContextRef c = _ctx;
    CGContextSaveGState(c);
    CGRect dirty;
    if (_tool == PaintToolPencil || (_tool == PaintToolBrush && _brushShape == PaintBrushRound)) {
        BOOL pencil = _tool == PaintToolPencil;
        CGFloat w = pencil ? _pencilWidth : _brushSize;
        CGContextSetShouldAntialias(c, !pencil);
        CGContextSetStrokeColorWithColor(c, _primaryColor.CGColor);
        CGContextSetLineWidth(c, w);
        CGContextSetLineCap(c, pencil ? kCGLineCapSquare : kCGLineCapRound);
        CGContextSetLineJoin(c, kCGLineJoinRound);
        CGPoint mid = CGPointMake((_last.x + p.x) / 2, (_last.y + p.y) / 2);
        if (first) {
            CGContextMoveToPoint(c, p.x, p.y);
            CGContextAddLineToPoint(c, p.x + .01, p.y);
            dirty = CGRectMake(p.x, p.y, 0, 0);
        } else if (pencil) {
            CGContextMoveToPoint(c, _last.x, _last.y);
            CGContextAddLineToPoint(c, p.x, p.y);
            dirty = CGRectUnion(CGRectMake(_last.x, _last.y, 0, 0), CGRectMake(p.x, p.y, 0, 0));
        } else {
            // Midpoint quadratic smoothing keeps fast brush strokes from looking faceted.
            CGContextMoveToPoint(c, _lastMid.x, _lastMid.y);
            CGContextAddQuadCurveToPoint(c, _last.x, _last.y, mid.x, mid.y);
            dirty = CGRectUnion(CGRectUnion(CGRectMake(_lastMid.x, _lastMid.y, 0, 0), CGRectMake(_last.x, _last.y, 0, 0)), CGRectMake(mid.x, mid.y, 0, 0));
        }
        CGContextStrokePath(c);
        dirty = CGRectInset(dirty, -w - 2, -w - 2);
        if (!first) _lastMid = mid;
    } else {
        BOOL eraser = _tool == PaintToolEraser;
        CGFloat size = eraser ? _eraserSize : _brushSize, half = size / 2;
        PaintBrushShape shape = eraser ? PaintBrushSquare : _brushShape;
        CGPoint a = first ? p : _last;
        CGContextSetFillColorWithColor(c, (eraser ? _secondaryColor : _primaryColor).CGColor);
        if (shape == PaintBrushSquare) {
            CGContextSetShouldAntialias(c, NO);
            int steps = MAX(1, (int)ceil(PaintDistance(a, p) / MAX(1, size / 4)));
            for (int i = 0; i <= steps; i++) {
                CGFloat t = (CGFloat)i / steps;
                CGContextFillRect(c, CGRectMake(round(a.x + (p.x - a.x) * t - half), round(a.y + (p.y - a.y) * t - half), size, size));
            }
        } else {
            // Calligraphy: sweep the slanted nib from the last point to this one.
            CGPoint o = shape == PaintBrushSlash ? CGPointMake(half, -half) : CGPointMake(half, half);
            CGContextSetShouldAntialias(c, YES);
            CGContextMoveToPoint(c, a.x + o.x, a.y + o.y);
            CGContextAddLineToPoint(c, p.x + o.x, p.y + o.y);
            CGContextAddLineToPoint(c, p.x - o.x, p.y - o.y);
            CGContextAddLineToPoint(c, a.x - o.x, a.y - o.y);
            CGContextClosePath(c);
            CGContextFillPath(c);
            CGContextSetStrokeColorWithColor(c, _primaryColor.CGColor);
            CGContextSetLineWidth(c, MAX(_pixelScale, size / 8));
            CGContextSetLineCap(c, kCGLineCapRound);
            CGContextMoveToPoint(c, p.x - o.x, p.y - o.y);
            CGContextAddLineToPoint(c, p.x + o.x, p.y + o.y);
            CGContextStrokePath(c);
        }
        dirty = CGRectInset(CGRectUnion(CGRectMake(a.x, a.y, 0, 0), CGRectMake(p.x, p.y, 0, 0)), -size - 2, -size - 2);
    }
    CGContextRestoreGState(c);
    _last = p;
    [self dirtyPixels:dirty];
}

- (void)finishStroke {
    if (_tool != PaintToolBrush || _brushShape != PaintBrushRound || CGPointEqualToPoint(_lastMid, _last)) return;
    CGContextRef c = _ctx;
    CGContextSaveGState(c);
    CGContextSetStrokeColorWithColor(c, _primaryColor.CGColor);
    CGContextSetLineWidth(c, _brushSize);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextMoveToPoint(c, _lastMid.x, _lastMid.y);
    CGContextAddLineToPoint(c, _last.x, _last.y);
    CGContextStrokePath(c);
    CGContextRestoreGState(c);
    [self dirtyPixels:CGRectInset(CGRectUnion(CGRectMake(_lastMid.x, _lastMid.y, 0, 0), CGRectMake(_last.x, _last.y, 0, 0)), -_brushSize - 2, -_brushSize - 2)];
}

- (void)spray {
    CGFloat r = _airbrushSize / 2, dot = _pixelScale;
    int count = MAX(4, (int)(r / 3));
    CGContextRef c = _ctx;
    CGContextSaveGState(c);
    CGContextSetShouldAntialias(c, NO);
    CGContextSetFillColorWithColor(c, _primaryColor.CGColor);
    for (int i = 0; i < count; i++) {
        CGFloat angle = arc4random_uniform(36000) / 36000.0 * 2 * M_PI, distance = r * sqrt(arc4random_uniform(10001) / 10000.0);
        CGContextFillRect(c, CGRectMake(floor(_last.x + cos(angle) * distance), floor(_last.y + sin(angle) * distance), dot, dot));
    }
    CGContextRestoreGState(c);
    [self dirtyPixels:CGRectInset(CGRectMake(_last.x, _last.y, 0, 0), -r - dot - 1, -r - dot - 1)];
}

- (void)stopSpray { [_sprayLink invalidate]; _sprayLink = nil; }

- (void)floodAt:(CGPoint)p {
    if (![self containsPixel:p]) return;
    [self beginOp];
    PaintIRect dirty;
    if (PaintFloodFill(_pixels, _w, _h, (int)p.x, (int)p.y, PaintPackColor(_primaryColor), _fillTolerance, &dirty)) {
        _opDirty = PaintIRectUnion(_opDirty, dirty);
        [self invalidatePixels:dirty];
    }
    [self endOp];
}

#pragma mark - Curve and polygon

- (UIBezierPath *)curvePath {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:_curveA];
    if (_curveStage == 0) [path addLineToPoint:_curveB];
    else [path addCurveToPoint:_curveB controlPoint1:_curveC1 controlPoint2:_curveC2];
    return path;
}
- (void)updateCurvePreview { [self showPreviewPath:[self curvePath] stroke:_primaryColor fill:nil width:_lineWidth dashed:NO]; }
- (void)commitCurve {
    if (_curveStage == 0) return;
    UIBezierPath *path = [self curvePath];
    _curveStage = 0;
    [self clearPreview];
    [self drawShape:path fillable:NO];
}

- (UIBezierPath *)polygonPathClosed:(BOOL)closed live:(BOOL)live {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [_polygon enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger i, BOOL *stop) {
        if (i) [path addLineToPoint:value.CGPointValue]; else [path moveToPoint:value.CGPointValue];
    }];
    if (live) [path addLineToPoint:_polygonLive];
    if (closed) [path closePath];
    return path;
}
- (void)updatePolygonPreview {
    UIBezierPath *path = [self polygonPathClosed:NO live:_touch != nil];
    // Ring the first corner so it's clear where to tap to close the shape.
    if (_polygon.count >= 3) {
        CGFloat r = 9 * _pixelScale / _zoomScale;
        CGPoint first = _polygon[0].CGPointValue;
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(first.x - r, first.y - r, r * 2, r * 2)]];
    }
    [self showPreviewPath:path stroke:_primaryColor fill:nil width:_lineWidth dashed:NO];
}
- (void)endPolygonAt:(CGPoint)p {
    CGPoint first = _polygon[0].CGPointValue, last = _polygon.lastObject.CGPointValue;
    CGFloat near = 24 * _pixelScale / _zoomScale;
    if (_polygonDragging) {
        _polygonDragging = NO;
        if (PaintDistance(p, first) >= 3 * _pixelScale) [_polygon addObject:[NSValue valueWithCGPoint:p]];
    } else if ((_polygon.count >= 3 && PaintDistance(p, first) < near) || (_polygon.count >= 2 && PaintDistance(p, last) < near / 2)) {
        [self commitPolygon];
        return;
    } else {
        [_polygon addObject:[NSValue valueWithCGPoint:p]];
    }
    [self updatePolygonPreview];
    [self.delegate canvasDidChange:self];
}
- (void)commitPolygon {
    if (!_polygon.count) return;
    BOOL enough = _polygon.count >= 2, closed = _polygon.count >= 3;
    UIBezierPath *path = [self polygonPathClosed:closed live:NO];
    [_polygon removeAllObjects];
    [self clearPreview];
    if (enough) [self drawShape:path fillable:closed]; else [self.delegate canvasDidChange:self];
}

#pragma mark - Text

- (UIFont *)textFontOfSize:(CGFloat)size { return [UIFont fontWithName:_fontName size:size] ?: [UIFont systemFontOfSize:size]; }

- (void)beginTextFrom:(CGPoint)a to:(CGPoint)b {
    CGFloat s = _pixelScale;
    if (a.x >= _w - 20 * s || a.y >= _h - 10 * s || a.x < 0 || a.y < 0) return;
    CGRect r = CGRectStandardize(CGRectMake(a.x, a.y, b.x - a.x, b.y - a.y));
    if (r.size.width < 40 * s) r.size.width = MIN(320 * s, _w - r.origin.x);
    UITextView *textView = [[UITextView alloc] initWithFrame:[self pointRect:r]];
    textView.delegate = self;
    textView.scrollEnabled = NO;
    textView.textContainerInset = UIEdgeInsetsZero;
    textView.textContainer.lineFragmentPadding = 0;
    textView.spellCheckingType = UITextSpellCheckingTypeNo;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.layer.borderColor = XPSelectionColor().CGColor;
    textView.layer.borderWidth = 1 / _zoomScale;
    textView.accessibilityLabel = @"Text box";
    _textView = textView;
    [self styleTextView];
    [self addSubview:textView];
    [textView becomeFirstResponder];
    [self.delegate canvasDidChange:self];
}

- (void)styleTextView {
    if (!_textView) return;
    _textView.font = [self textFontOfSize:_fontSize / _pixelScale];
    _textView.textColor = _primaryColor;
    _textView.backgroundColor = _opaqueText ? _secondaryColor : UIColor.clearColor;
    [self fitTextView];
}

- (void)fitTextView {
    CGRect f = _textView.frame;
    f.size.height = ceil(MAX([_textView sizeThatFits:CGSizeMake(f.size.width, CGFLOAT_MAX)].height, _textView.font.lineHeight));
    _textView.frame = f;
}

- (void)textViewDidChange:(UITextView *)textView { [self fitTextView]; }

- (void)removeTextView {
    UITextView *textView = _textView;
    _textView = nil;
    [textView resignFirstResponder];
    [textView removeFromSuperview];
}

- (void)commitText {
    if (!_textView) return;
    NSString *text = _textView.text;
    CGRect f = _textView.frame;
    [self removeTextView];
    if (!text.length) { [self.delegate canvasDidChange:self]; return; }
    CGFloat s = _pixelScale;
    CGRect r = CGRectMake(f.origin.x * s, f.origin.y * s, f.size.width * s, f.size.height * s);
    [self beginOp];
    UIGraphicsPushContext(_ctx);
    if (_opaqueText) { [_secondaryColor setFill]; UIRectFill(r); }
    [text drawWithRect:r options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: [self textFontOfSize:_fontSize], NSForegroundColorAttributeName: _primaryColor} context:nil];
    UIGraphicsPopContext();
    [self dirtyPixels:CGRectInset(r, -_fontSize / 2, -_fontSize / 2)];
    [self endOp];
}

#pragma mark - Selection

- (void)beginSelectionAt:(CGPoint)p {
    if (_selImage) {
        CGFloat slop = 22 * _pixelScale / _zoomScale;
        _selDragStart = _selFrame;
        _dragAnchor = p;
        if (PaintDistance(p, CGPointMake(CGRectGetMaxX(_selFrame), CGRectGetMaxY(_selFrame))) < slop) { _selDrag = PaintSelectionDragResize; return; }
        if (CGRectContainsPoint(CGRectInset(_selFrame, -slop / 2, -slop / 2), p)) { _selDrag = PaintSelectionDragMove; return; }
        [self commitSelection];
    }
    _selDrag = PaintSelectionDragCreate;
    _lasso = [NSMutableArray arrayWithObject:[NSValue valueWithCGPoint:p]];
}

- (UIBezierPath *)lassoPath {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [_lasso enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger i, BOOL *stop) {
        if (i) [path addLineToPoint:value.CGPointValue]; else [path moveToPoint:value.CGPointValue];
    }];
    return path;
}

- (void)moveSelectionTo:(CGPoint)p {
    CGFloat dx = p.x - _dragAnchor.x, dy = p.y - _dragAnchor.y;
    switch (_selDrag) {
        case PaintSelectionDragCreate:
            if (_tool == PaintToolFreeSelect) {
                [_lasso addObject:[NSValue valueWithCGPoint:p]];
                [self showPreviewPath:[self lassoPath] stroke:UIColor.blackColor fill:nil width:0 dashed:YES];
            } else {
                CGRect r = CGRectStandardize(CGRectMake(_start.x, _start.y, p.x - _start.x, p.y - _start.y));
                [self showPreviewPath:[UIBezierPath bezierPathWithRect:r] stroke:UIColor.blackColor fill:nil width:0 dashed:YES];
                [self.delegate canvas:self showStatus:[NSString stringWithFormat:@"%d × %dpx", (int)r.size.width, (int)r.size.height]];
            }
            break;
        case PaintSelectionDragMove:
            _selFrame.origin = CGPointMake(_selDragStart.origin.x + dx, _selDragStart.origin.y + dy);
            [self layoutSelection];
            break;
        case PaintSelectionDragResize:
            _selFrame.size = CGSizeMake(MAX(2, _selDragStart.size.width + dx), MAX(2, _selDragStart.size.height + dy));
            [self layoutSelection];
            [self.delegate canvas:self showStatus:[NSString stringWithFormat:@"%d × %dpx", (int)_selFrame.size.width, (int)_selFrame.size.height]];
            break;
        default: break;
    }
}

- (void)endSelectionAt:(CGPoint)p {
    PaintSelectionDrag drag = _selDrag;
    _selDrag = PaintSelectionDragNone;
    if (drag != PaintSelectionDragCreate) return;
    [self clearPreview];
    UIBezierPath *outline = nil;
    CGRect box;
    if (_tool == PaintToolFreeSelect) {
        if (_lasso.count < 3) return;
        outline = [self lassoPath];
        [outline closePath];
        box = CGPathGetPathBoundingBox(outline.CGPath);
    } else {
        box = CGRectStandardize(CGRectMake(_start.x, _start.y, p.x - _start.x, p.y - _start.y));
    }
    PaintIRect r = [self clampedIRect:box];
    if (r.w < 2 || r.h < 2) return;
    [self liftRect:r outline:outline];
}

- (void)liftRect:(PaintIRect)r outline:(UIBezierPath *)outline {
    [self beginOp];
    NSMutableData *data = [NSMutableData dataWithLength:(size_t)r.w * r.h * 4];
    PaintCopyRect(_pixels, _w, r, data.mutableBytes);
    UIBezierPath *local = nil;
    if (outline) {
        local = [outline copy];
        [local applyTransform:CGAffineTransformMakeTranslation(-r.x, -r.y)];
        CGImageRef full = PaintCreateImage(data, r.w, r.h, YES);
        NSMutableData *masked = [NSMutableData dataWithLength:data.length];
        CGContextRef mc = PaintCreateContext(r.w, r.h, masked.mutableBytes);
        CGContextSetShouldAntialias(mc, NO);
        CGContextAddPath(mc, local.CGPath);
        CGContextClip(mc);
        UIGraphicsPushContext(mc);
        [[UIImage imageWithCGImage:full] drawInRect:CGRectMake(0, 0, r.w, r.h)];
        UIGraphicsPopContext();
        CGContextRelease(mc);
        CGImageRelease(full);
        data = masked;
    }
    CGImageRelease(_selOpaque);
    _selOpaque = PaintCreateImage(data, r.w, r.h, NO);
    // Lifting leaves the secondary color behind, as in XP.
    CGContextRef c = _ctx;
    CGContextSaveGState(c);
    CGContextSetShouldAntialias(c, NO);
    CGContextSetFillColorWithColor(c, _secondaryColor.CGColor);
    if (outline) { CGContextAddPath(c, outline.CGPath); CGContextFillPath(c); } else CGContextFillRect(c, CGRectMake(r.x, r.y, r.w, r.h));
    CGContextRestoreGState(c);
    [self dirtyPixels:CGRectMake(r.x, r.y, r.w, r.h)];
    _selOutline = local;
    _selNaturalSize = CGSizeMake(r.w, r.h);
    _selFrame = CGRectMake(r.x, r.y, r.w, r.h);
    [self rebuildSelectionImage];
    [self showSelection];
    [self.delegate canvasDidChange:self];
}

- (void)rebuildSelectionImage {
    if (!_selOpaque) return;
    CGImageRelease(_selImage);
    if (_transparentSelection) {
        NSMutableData *data = PaintPixelsOfImage(_selOpaque);
        int w = (int)CGImageGetWidth(_selOpaque), h = (int)CGImageGetHeight(_selOpaque);
        PaintClearColor(data.mutableBytes, (size_t)w * h, PaintPackColor(_secondaryColor));
        _selImage = PaintCreateImage(data, w, h, NO);
    } else {
        _selImage = CGImageRetain(_selOpaque);
    }
    CALayer *layer = _selLayer;
    CGImageRef image = _selImage;
    XPNoAnimation(^{ layer.contents = (__bridge id)image; });
}

- (void)showSelection {
    if (!_selLayer) {
        _selLayer = [CALayer layer];
        _selLayer.magnificationFilter = kCAFilterNearest;
        _antsLight = [CAShapeLayer layer];
        _antsLight.strokeColor = UIColor.whiteColor.CGColor;
        _antsLight.fillColor = nil;
        _antsDark = [CAShapeLayer layer];
        _antsDark.strokeColor = UIColor.blackColor.CGColor;
        _antsDark.fillColor = nil;
        _handle = [CALayer layer];
        _handle.backgroundColor = XPSelectionColor().CGColor;
        _handle.borderColor = UIColor.whiteColor.CGColor;
        for (CALayer *layer in @[_selLayer, _antsLight, _antsDark, _handle]) [self.layer addSublayer:layer];
    }
    CALayer *layer = _selLayer;
    CGImageRef image = _selImage;
    XPNoAnimation(^{ layer.contents = (__bridge id)image; });
    [self layoutSelection];
}

- (void)layoutSelection {
    if (!_selLayer) return;
    CGFloat s = _pixelScale, z = _zoomScale, hs = 14 / z;
    CGRect f = [self pointRect:_selFrame];
    UIBezierPath *outline = _selOutline ? [_selOutline copy] : [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, _selNaturalSize.width, _selNaturalSize.height)];
    [outline applyTransform:CGAffineTransformMakeScale(_selFrame.size.width / _selNaturalSize.width / s, _selFrame.size.height / _selNaturalSize.height / s)];
    [outline applyTransform:CGAffineTransformMakeTranslation(f.origin.x, f.origin.y)];
    CALayer *selLayer = _selLayer, *handle = _handle;
    CAShapeLayer *light = _antsLight, *dark = _antsDark;
    XPNoAnimation(^{
        selLayer.frame = f;
        for (CAShapeLayer *ants in @[light, dark]) { ants.frame = self.bounds; ants.path = outline.CGPath; ants.lineWidth = 1.2 / z; }
        dark.lineDashPattern = @[@(4 / z), @(4 / z)];
        handle.frame = CGRectMake(CGRectGetMaxX(f) - hs / 2, CGRectGetMaxY(f) - hs / 2, hs, hs);
        handle.borderWidth = 1.5 / z;
    });
    if (z != _antsZoom && !UIAccessibilityIsReduceMotionEnabled()) {
        _antsZoom = z;
        CABasicAnimation *march = [CABasicAnimation animationWithKeyPath:@"lineDashPhase"];
        march.fromValue = @0;
        march.toValue = @(8 / z);
        march.duration = .5;
        march.repeatCount = HUGE_VALF;
        [_antsDark addAnimation:march forKey:@"march"];
    }
}

- (void)dropSelection {
    [_selLayer removeFromSuperlayer];
    [_antsLight removeFromSuperlayer];
    [_antsDark removeFromSuperlayer];
    [_handle removeFromSuperlayer];
    _selLayer = _handle = nil;
    _antsLight = _antsDark = nil;
    _antsZoom = 0;
    CGImageRelease(_selOpaque);
    CGImageRelease(_selImage);
    _selOpaque = _selImage = NULL;
    _selOutline = nil;
    _selDrag = PaintSelectionDragNone;
}

- (void)commitSelection {
    if (!_selImage) return;
    CGRect f = CGRectMake(round(_selFrame.origin.x), round(_selFrame.origin.y), round(_selFrame.size.width), round(_selFrame.size.height));
    CGContextRef c = _ctx;
    CGContextSaveGState(c);
    CGContextSetInterpolationQuality(c, CGSizeEqualToSize(f.size, _selNaturalSize) ? kCGInterpolationNone : kCGInterpolationHigh);
    UIGraphicsPushContext(c);
    [[UIImage imageWithCGImage:_selImage] drawInRect:f];
    UIGraphicsPopContext();
    CGContextRestoreGState(c);
    [self dirtyPixels:f];
    [self dropSelection];
    [self endOp];
}

- (void)selectAll {
    [self cancelTouch];
    [self commitPending];
    [self liftRect:PaintIRectMake(0, 0, _w, _h) outline:nil];
}

- (void)copySelection { if (_selImage) UIPasteboard.generalPasteboard.image = [UIImage imageWithCGImage:_selImage]; }
- (void)cutSelection { [self copySelection]; [self deleteSelection]; }
- (void)deleteSelection {
    if (!_selImage) return;
    [self dropSelection];
    [self endOp];
}

- (BOOL)pasteImage:(UIImage *)image {
    if (!image || image.size.width < 1 || image.size.height < 1) return NO;
    [self cancelTouch];
    [self commitPending];
    CGSize size = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
    CGFloat fit = MIN(1, MIN(_w / size.width, _h / size.height));
    int w = MAX(1, (int)round(size.width * fit)), h = MAX(1, (int)round(size.height * fit));
    NSMutableData *data = [NSMutableData dataWithLength:(size_t)w * h * 4];
    CGContextRef c = PaintCreateContext(w, h, data.mutableBytes);
    UIGraphicsPushContext(c);
    [image drawInRect:CGRectMake(0, 0, w, h)];
    UIGraphicsPopContext();
    CGContextRelease(c);
    [self beginOp];
    CGImageRelease(_selOpaque);
    _selOpaque = PaintCreateImage(data, w, h, NO);
    CGRect visible = [self.delegate visibleRectForCanvas:self];
    CGFloat x = MAX(0, MIN(visible.origin.x * _pixelScale + 8 * _pixelScale, _w - w)), y = MAX(0, MIN(visible.origin.y * _pixelScale + 8 * _pixelScale, _h - h));
    _selOutline = nil;
    _selNaturalSize = CGSizeMake(w, h);
    _selFrame = CGRectMake(round(x), round(y), w, h);
    [self rebuildSelectionImage];
    [self showSelection];
    [self.delegate canvasDidChange:self];
    return YES;
}

#pragma mark - Image menu

- (void)applyTransform:(PaintTransform)op {
    [self cancelTouch];
    [self commitText];
    [self commitCurve];
    [self commitPolygon];
    if (_selImage) { [self transformSelection:op]; return; }
    if (op == PaintTransformRotateCW || op == PaintTransformRotateCCW) {
        [_history recordChange:[self wholePatch]];
        uint32_t *rotated = malloc((size_t)_w * _h * 4);
        PaintRotate90(_pixels, _w, _h, rotated, op == PaintTransformRotateCW);
        [self replaceBufferWidth:_h height:_w pixels:rotated];
        [self changed];
        [self.delegate canvasDidResize:self];
        return;
    }
    [self beginOp];
    if (op == PaintTransformFlipH || op == PaintTransformRotate180) PaintFlipHorizontal(_pixels, _w, _h);
    if (op == PaintTransformFlipV || op == PaintTransformRotate180) PaintFlipVertical(_pixels, _w, _h);
    if (op == PaintTransformInvert) PaintInvert(_pixels, (size_t)_w * _h);
    [self dirtyPixels:CGRectMake(0, 0, _w, _h)];
    [self endOp];
}

- (void)transformSelection:(PaintTransform)op {
    int w = (int)CGImageGetWidth(_selOpaque), h = (int)CGImageGetHeight(_selOpaque), nw = w, nh = h;
    NSMutableData *data = PaintPixelsOfImage(_selOpaque), *result = data;
    CGAffineTransform t = CGAffineTransformIdentity;
    switch (op) {
        case PaintTransformFlipH: PaintFlipHorizontal(data.mutableBytes, w, h); t = CGAffineTransformMake(-1, 0, 0, 1, w, 0); break;
        case PaintTransformFlipV: PaintFlipVertical(data.mutableBytes, w, h); t = CGAffineTransformMake(1, 0, 0, -1, 0, h); break;
        case PaintTransformRotate180: PaintFlipHorizontal(data.mutableBytes, w, h); PaintFlipVertical(data.mutableBytes, w, h); t = CGAffineTransformMake(-1, 0, 0, -1, w, h); break;
        case PaintTransformRotateCW: case PaintTransformRotateCCW:
            result = [NSMutableData dataWithLength:data.length];
            PaintRotate90(data.bytes, w, h, result.mutableBytes, op == PaintTransformRotateCW);
            nw = h; nh = w;
            t = op == PaintTransformRotateCW ? CGAffineTransformMake(0, 1, -1, 0, h, 0) : CGAffineTransformMake(0, -1, 1, 0, 0, w);
            break;
        case PaintTransformInvert: PaintInvert(data.mutableBytes, (size_t)w * h); break;
    }
    CGImageRelease(_selOpaque);
    _selOpaque = PaintCreateImage(result, nw, nh, NO);
    [_selOutline applyTransform:t];
    if (nw != w) {
        CGPoint center = CGPointMake(CGRectGetMidX(_selFrame), CGRectGetMidY(_selFrame));
        CGSize size = CGSizeMake(_selFrame.size.height, _selFrame.size.width);
        _selFrame = CGRectMake(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height);
        _selNaturalSize = CGSizeMake(nw, nh);
    }
    [self rebuildSelectionImage];
    [self layoutSelection];
}

- (void)flipHorizontal { [self applyTransform:PaintTransformFlipH]; }
- (void)flipVertical { [self applyTransform:PaintTransformFlipV]; }
- (void)invertColors { [self applyTransform:PaintTransformInvert]; }
- (void)rotateQuarterTurns:(NSInteger)turns { [self applyTransform:turns == 1 ? PaintTransformRotateCW : turns == -1 ? PaintTransformRotateCCW : PaintTransformRotate180]; }

- (void)clearImage {
    [self cancelTouch];
    if (_selImage) { [self deleteSelection]; return; }
    [self commitPending];
    [self beginOp];
    CGContextSetFillColorWithColor(_ctx, _secondaryColor.CGColor);
    CGContextFillRect(_ctx, CGRectMake(0, 0, _w, _h));
    [self dirtyPixels:CGRectMake(0, 0, _w, _h)];
    [self endOp];
}
@end
