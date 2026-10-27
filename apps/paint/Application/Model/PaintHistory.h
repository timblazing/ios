#import "PaintPixels.h"

// The pixels a change overwrote. A whole patch holds the entire canvas at its old size, so it can undo size changes.
@interface PaintPatch : NSObject
@property(nonatomic) PaintIRect rect;
@property(nonatomic) int canvasWidth, canvasHeight;
@property(nonatomic) BOOL whole;
@property(nonatomic, strong) NSData *pixels;
+ (instancetype)patchWithRect:(PaintIRect)rect canvasWidth:(int)width height:(int)height pixels:(NSData *)pixels whole:(BOOL)whole;
@end

@interface PaintHistory : NSObject
- (instancetype)initWithByteLimit:(NSUInteger)byteLimit maxSteps:(NSUInteger)maxSteps;
@property(nonatomic, readonly) BOOL canUndo, canRedo;
@property(nonatomic, readonly) NSUInteger byteCount, undoCount;
- (void)recordChange:(PaintPatch *)patch;
- (PaintPatch *)takeUndo;
- (PaintPatch *)takeRedo;
- (void)pushUndo:(PaintPatch *)patch;
- (void)pushRedo:(PaintPatch *)patch;
- (void)removeAll;
@end
