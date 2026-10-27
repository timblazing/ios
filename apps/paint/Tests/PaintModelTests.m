#import "../Application/Model/PaintHistory.h"
#include <stdio.h>
#include <stdlib.h>

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { failures++; fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); } } while (0)

static void testFloodFill(void) {
    uint32_t W = PaintPackRGBA(255, 255, 255, 255), K = PaintPackRGBA(0, 0, 0, 255), R = PaintPackRGBA(255, 0, 0, 255);
    // 5x5 white with a black ring around the centre pixel.
    uint32_t px[25];
    for (int i = 0; i < 25; i++) px[i] = W;
    for (int y = 1; y <= 3; y++) for (int x = 1; x <= 3; x++) if (!(x == 2 && y == 2)) px[y * 5 + x] = K;
    PaintIRect dirty;
    CHECK(PaintFloodFill(px, 5, 5, 0, 0, R, 0, &dirty));
    CHECK(px[0] == R && px[24] == R && px[12] == W && px[6] == K);
    CHECK(dirty.x == 0 && dirty.y == 0 && dirty.w == 5 && dirty.h == 5);
    CHECK(PaintFloodFill(px, 5, 5, 2, 2, R, 0, &dirty));
    CHECK(px[12] == R && dirty.w == 1 && dirty.h == 1);
    CHECK(!PaintFloodFill(px, 5, 5, 2, 2, R, 0, NULL));
    CHECK(!PaintFloodFill(px, 5, 5, 9, 9, R, 0, NULL));
}

static void testToleranceTerminates(void) {
    uint32_t a = PaintPackRGBA(200, 200, 200, 255), b = PaintPackRGBA(210, 210, 210, 255), fill = PaintPackRGBA(205, 205, 205, 255);
    uint32_t px[64];
    for (int i = 0; i < 64; i++) px[i] = (i % 2) ? a : b;
    CHECK(PaintFloodFill(px, 8, 8, 0, 0, fill, 32, NULL));
    for (int i = 0; i < 64; i++) CHECK(px[i] == fill);
    uint32_t far = PaintPackRGBA(10, 10, 10, 255);
    px[9] = far;
    PaintFloodFill(px, 8, 8, 0, 0, a, 0, NULL);
    CHECK(px[9] == far);
}

static void testTransforms(void) {
    uint32_t px[6] = {1, 2, 3, 4, 5, 6}; // 3 wide, 2 tall
    uint32_t cw[6], ccw[6];
    PaintRotate90(px, 3, 2, cw, true);
    uint32_t expectCW[6] = {4, 1, 5, 2, 6, 3};
    for (int i = 0; i < 6; i++) CHECK(cw[i] == expectCW[i]);
    PaintRotate90(px, 3, 2, ccw, false);
    uint32_t expectCCW[6] = {3, 6, 2, 5, 1, 4};
    for (int i = 0; i < 6; i++) CHECK(ccw[i] == expectCCW[i]);
    PaintFlipHorizontal(px, 3, 2);
    CHECK(px[0] == 3 && px[2] == 1 && px[3] == 6);
    PaintFlipVertical(px, 3, 2);
    CHECK(px[0] == 6 && px[5] == 1);
    uint32_t c = PaintPackRGBA(10, 20, 30, 255);
    PaintInvert(&c, 1);
    CHECK(c == PaintPackRGBA(245, 235, 225, 255));
    uint32_t clear[3] = {c, 7, c};
    PaintClearColor(clear, 3, c);
    CHECK(clear[0] == 0 && clear[1] == 7 && clear[2] == 0);
}

static void testRects(void) {
    uint32_t src[16];
    for (int i = 0; i < 16; i++) src[i] = (uint32_t)i;
    uint32_t sub[4];
    PaintCopyRect(src, 4, PaintIRectMake(1, 1, 2, 2), sub);
    CHECK(sub[0] == 5 && sub[1] == 6 && sub[2] == 9 && sub[3] == 10);
    uint32_t dst[16] = {0};
    PaintPasteRect(dst, 4, PaintIRectMake(2, 2, 2, 2), sub);
    CHECK(dst[10] == 5 && dst[15] == 10 && dst[0] == 0);
    PaintIRect u = PaintIRectUnion(PaintIRectMake(0, 0, 2, 2), PaintIRectMake(5, 5, 1, 1));
    CHECK(u.w == 6 && u.h == 6);
    CHECK(PaintIRectIsEmpty(PaintIRectIntersect(PaintIRectMake(0, 0, 2, 2), PaintIRectMake(3, 3, 2, 2))));
    CHECK(PaintIRectUnion(PaintIRectMake(0, 0, 0, 0), PaintIRectMake(3, 3, 1, 1)).x == 3);
}

static PaintPatch *patchOfBytes(NSUInteger n) { return [PaintPatch patchWithRect:PaintIRectMake(0, 0, 1, 1) canvasWidth:1 height:1 pixels:[NSMutableData dataWithLength:n] whole:NO]; }

static void testHistory(void) {
    PaintHistory *h = [[PaintHistory alloc] initWithByteLimit:100 maxSteps:3];
    CHECK(!h.canUndo && !h.canRedo);
    for (int i = 0; i < 5; i++) [h recordChange:patchOfBytes(10)];
    CHECK(h.undoCount == 3 && h.byteCount == 30);
    PaintPatch *p = [h takeUndo];
    [h pushRedo:p];
    CHECK(h.canRedo && h.undoCount == 2);
    [h recordChange:patchOfBytes(10)];
    CHECK(!h.canRedo && h.byteCount == 30);
    [h recordChange:patchOfBytes(500)];
    CHECK(h.undoCount == 1 && h.byteCount == 500);
    [h removeAll];
    CHECK(h.byteCount == 0 && !h.canUndo);
}

int main(void) {
    @autoreleasepool {
        testFloodFill(); testToleranceTerminates(); testTransforms(); testRects(); testHistory();
    }
    if (failures) { fprintf(stderr, "%d failure(s)\n", failures); return 1; }
    printf("All model tests passed.\n");
    return 0;
}
