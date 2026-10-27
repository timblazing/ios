#import <UIKit/UIKit.h>

// Order matches the toolbox: two columns, left to right, top to bottom, as in XP Paint.
typedef NS_ENUM(NSInteger, PaintTool) {
    PaintToolFreeSelect, PaintToolSelect, PaintToolEraser, PaintToolFill, PaintToolPicker, PaintToolMagnifier,
    PaintToolPencil, PaintToolBrush, PaintToolAirbrush, PaintToolText, PaintToolLine, PaintToolCurve,
    PaintToolRectangle, PaintToolPolygon, PaintToolEllipse, PaintToolRoundedRect, PaintToolCount
};
typedef NS_ENUM(NSInteger, PaintBrushShape) { PaintBrushRound, PaintBrushSquare, PaintBrushSlash, PaintBrushBackslash };
typedef NS_ENUM(NSInteger, PaintFillStyle) { PaintFillOutline, PaintFillOutlineAndFill, PaintFillSolid };

@class PaintCanvasView;

@protocol PaintCanvasDelegate <NSObject>
- (void)canvasDidChange:(PaintCanvasView *)canvas;
- (void)canvasDidResize:(PaintCanvasView *)canvas;
- (void)canvas:(PaintCanvasView *)canvas didPickColor:(UIColor *)color;
- (void)canvas:(PaintCanvasView *)canvas didRequestZoomAtPoint:(CGPoint)point;
- (void)canvas:(PaintCanvasView *)canvas showStatus:(NSString *)status;
- (CGRect)visibleRectForCanvas:(PaintCanvasView *)canvas;
@end

// A bitmap canvas. Sizes and positions given to it are in image pixels; the view is laid out in points (pixels / pixelScale).
@interface PaintCanvasView : UIView <UITextViewDelegate>
- (instancetype)initWithPixelWidth:(int)width height:(int)height scale:(CGFloat)scale;
@property(nonatomic, weak) id<PaintCanvasDelegate> delegate;
@property(nonatomic) PaintTool tool;
@property(nonatomic, strong) UIColor *primaryColor, *secondaryColor;
@property(nonatomic) CGFloat pencilWidth, lineWidth, brushSize, eraserSize, airbrushSize, fontSize;
@property(nonatomic) PaintBrushShape brushShape;
@property(nonatomic) PaintFillStyle fillStyle;
@property(nonatomic) int fillTolerance;
@property(nonatomic) BOOL transparentSelection, opaqueText;
@property(nonatomic, copy) NSString *fontName;
@property(nonatomic) CGFloat zoomScale;
@property(nonatomic, readonly) int pixelWidth, pixelHeight;
@property(nonatomic, readonly) CGFloat pixelScale;
@property(nonatomic, readonly) BOOL canUndo, canRedo, hasSelection, hasChanges;
@property(nonatomic, readonly) CGRect activeTextRect;

- (void)undo;
- (void)redo;
- (void)commitPending;
- (void)cancelTouch;
- (void)resetWithPixelWidth:(int)width height:(int)height image:(UIImage *)image;
- (void)resizeCanvasToWidth:(int)width height:(int)height;
- (UIImage *)snapshotImage;
- (void)markSaved;
- (void)markUnsaved;

- (void)selectAll;
- (void)copySelection;
- (void)cutSelection;
- (void)deleteSelection;
- (BOOL)pasteImage:(UIImage *)image;

- (void)flipHorizontal;
- (void)flipVertical;
- (void)rotateQuarterTurns:(NSInteger)turns;
- (void)invertColors;
- (void)clearImage;
@end
