#import "PaintHistory.h"

@implementation PaintPatch
+ (instancetype)patchWithRect:(PaintIRect)rect canvasWidth:(int)width height:(int)height pixels:(NSData *)pixels whole:(BOOL)whole {
    PaintPatch *patch = [self new];
    patch.rect = rect; patch.canvasWidth = width; patch.canvasHeight = height; patch.pixels = pixels; patch.whole = whole;
    return patch;
}
@end

@implementation PaintHistory {
    NSMutableArray<PaintPatch *> *_undo, *_redo;
    NSUInteger _byteLimit, _maxSteps, _bytes;
}

- (instancetype)initWithByteLimit:(NSUInteger)byteLimit maxSteps:(NSUInteger)maxSteps {
    if ((self = [super init])) { _undo = [NSMutableArray array]; _redo = [NSMutableArray array]; _byteLimit = byteLimit; _maxSteps = maxSteps; }
    return self;
}
- (BOOL)canUndo { return _undo.count > 0; }
- (BOOL)canRedo { return _redo.count > 0; }
- (NSUInteger)byteCount { return _bytes; }
- (NSUInteger)undoCount { return _undo.count; }

- (void)recordChange:(PaintPatch *)patch {
    for (PaintPatch *p in _redo) _bytes -= p.pixels.length;
    [_redo removeAllObjects];
    [self pushUndo:patch];
}
- (void)pushUndo:(PaintPatch *)patch { [_undo addObject:patch]; _bytes += patch.pixels.length; [self trim]; }
- (void)pushRedo:(PaintPatch *)patch { [_redo addObject:patch]; _bytes += patch.pixels.length; [self trim]; }
- (PaintPatch *)take:(NSMutableArray *)stack {
    PaintPatch *patch = stack.lastObject;
    if (patch) { [stack removeLastObject]; _bytes -= patch.pixels.length; }
    return patch;
}
- (PaintPatch *)takeUndo { return [self take:_undo]; }
- (PaintPatch *)takeRedo { return [self take:_redo]; }
- (void)removeAll { [_undo removeAllObjects]; [_redo removeAllObjects]; _bytes = 0; }

// Drops the oldest steps first; the newest undo and redo always survive so the last action can be reversed.
- (void)trim {
    while (_undo.count > 1 && (_bytes > _byteLimit || _undo.count > _maxSteps)) { _bytes -= _undo[0].pixels.length; [_undo removeObjectAtIndex:0]; }
    while (_redo.count > 1 && _bytes > _byteLimit) { _bytes -= _redo[0].pixels.length; [_redo removeObjectAtIndex:0]; }
}
@end
