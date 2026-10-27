#import <Foundation/Foundation.h>
#include <stdbool.h>
#include <stdint.h>

// Pixel buffers are tightly packed 32-bit RGBA in memory order (byte 0 = red), premultiplied, row 0 at the top.
typedef struct { int x, y, w, h; } PaintIRect;

static inline PaintIRect PaintIRectMake(int x, int y, int w, int h) { PaintIRect r = {x, y, w, h}; return r; }
bool PaintIRectIsEmpty(PaintIRect r);
PaintIRect PaintIRectUnion(PaintIRect a, PaintIRect b);
PaintIRect PaintIRectIntersect(PaintIRect a, PaintIRect b);

uint32_t PaintPackRGBA(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void PaintUnpackRGBA(uint32_t p, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a);

// Scanline flood fill from (x, y). tolerance is the largest per-channel difference from the seed that still counts as the same color.
bool PaintFloodFill(uint32_t *px, int w, int h, int x, int y, uint32_t color, int tolerance, PaintIRect *dirty);
void PaintCopyRect(const uint32_t *src, int srcW, PaintIRect r, uint32_t *dst);
void PaintPasteRect(uint32_t *dst, int dstW, PaintIRect r, const uint32_t *src);
void PaintFlipHorizontal(uint32_t *px, int w, int h);
void PaintFlipVertical(uint32_t *px, int w, int h);
// dst must hold w*h pixels; it comes out h wide and w tall.
void PaintRotate90(const uint32_t *src, int w, int h, uint32_t *dst, bool clockwise);
void PaintInvert(uint32_t *px, size_t count);
void PaintClearColor(uint32_t *px, size_t count, uint32_t color);
