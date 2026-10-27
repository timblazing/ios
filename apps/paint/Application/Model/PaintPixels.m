#import "PaintPixels.h"
#include <stdlib.h>
#include <string.h>

bool PaintIRectIsEmpty(PaintIRect r) { return r.w <= 0 || r.h <= 0; }

PaintIRect PaintIRectUnion(PaintIRect a, PaintIRect b) {
    if (PaintIRectIsEmpty(a)) return b;
    if (PaintIRectIsEmpty(b)) return a;
    int x0 = MIN(a.x, b.x), y0 = MIN(a.y, b.y), x1 = MAX(a.x + a.w, b.x + b.w), y1 = MAX(a.y + a.h, b.y + b.h);
    return PaintIRectMake(x0, y0, x1 - x0, y1 - y0);
}

PaintIRect PaintIRectIntersect(PaintIRect a, PaintIRect b) {
    int x0 = MAX(a.x, b.x), y0 = MAX(a.y, b.y), x1 = MIN(a.x + a.w, b.x + b.w), y1 = MIN(a.y + a.h, b.y + b.h);
    if (x1 <= x0 || y1 <= y0) return PaintIRectMake(0, 0, 0, 0);
    return PaintIRectMake(x0, y0, x1 - x0, y1 - y0);
}

uint32_t PaintPackRGBA(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    uint8_t bytes[4] = {r, g, b, a};
    uint32_t p;
    memcpy(&p, bytes, 4);
    return p;
}

void PaintUnpackRGBA(uint32_t p, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a) {
    uint8_t bytes[4];
    memcpy(bytes, &p, 4);
    *r = bytes[0]; *g = bytes[1]; *b = bytes[2]; *a = bytes[3];
}

static inline bool PaintMatches(uint32_t p, uint32_t seed, int tolerance) {
    if (p == seed) return true;
    if (tolerance <= 0) return false;
    for (int shift = 0; shift < 32; shift += 8) {
        int d = (int)((p >> shift) & 0xff) - (int)((seed >> shift) & 0xff);
        if (d > tolerance || d < -tolerance) return false;
    }
    return true;
}

bool PaintFloodFill(uint32_t *px, int w, int h, int x, int y, uint32_t color, int tolerance, PaintIRect *dirty) {
    if (x < 0 || y < 0 || x >= w || y >= h) return false;
    uint32_t seed = px[(size_t)y * w + x];
    if (seed == color && tolerance <= 0) return false;
    // Pixels already filled are tracked separately: with a tolerance, the fill color itself may still match the seed.
    uint8_t *done = calloc((size_t)w * h, 1);
    size_t cap = 4096, count = 1;
    int *stack = malloc(cap * 2 * sizeof(int));
    if (!done || !stack) { free(done); free(stack); return false; }
    stack[0] = x; stack[1] = y;
    int minX = x, maxX = x, minY = y, maxY = y;
    bool changed = false;
    while (count) {
        count--;
        int sx = stack[count * 2], sy = stack[count * 2 + 1];
        uint32_t *row = px + (size_t)sy * w;
        uint8_t *drow = done + (size_t)sy * w;
        if (drow[sx] || !PaintMatches(row[sx], seed, tolerance)) continue;
        int lx = sx, rx = sx;
        while (lx > 0 && !drow[lx - 1] && PaintMatches(row[lx - 1], seed, tolerance)) lx--;
        while (rx < w - 1 && !drow[rx + 1] && PaintMatches(row[rx + 1], seed, tolerance)) rx++;
        for (int i = lx; i <= rx; i++) { row[i] = color; drow[i] = 1; }
        changed = true;
        minX = MIN(minX, lx); maxX = MAX(maxX, rx); minY = MIN(minY, sy); maxY = MAX(maxY, sy);
        for (int ny = sy - 1; ny <= sy + 1; ny += 2) {
            if (ny < 0 || ny >= h) continue;
            uint32_t *nrow = px + (size_t)ny * w;
            uint8_t *ndone = done + (size_t)ny * w;
            bool inRun = false;
            for (int i = lx; i <= rx; i++) {
                bool match = !ndone[i] && PaintMatches(nrow[i], seed, tolerance);
                if (match && !inRun) {
                    if (count == cap) {
                        cap *= 2;
                        int *grown = realloc(stack, cap * 2 * sizeof(int));
                        if (!grown) { free(stack); free(done); return changed; }
                        stack = grown;
                    }
                    stack[count * 2] = i; stack[count * 2 + 1] = ny; count++;
                }
                inRun = match;
            }
        }
    }
    free(stack);
    free(done);
    if (dirty) *dirty = PaintIRectMake(minX, minY, maxX - minX + 1, maxY - minY + 1);
    return changed;
}

void PaintCopyRect(const uint32_t *src, int srcW, PaintIRect r, uint32_t *dst) {
    for (int y = 0; y < r.h; y++) memcpy(dst + (size_t)y * r.w, src + (size_t)(r.y + y) * srcW + r.x, (size_t)r.w * 4);
}

void PaintPasteRect(uint32_t *dst, int dstW, PaintIRect r, const uint32_t *src) {
    for (int y = 0; y < r.h; y++) memcpy(dst + (size_t)(r.y + y) * dstW + r.x, src + (size_t)y * r.w, (size_t)r.w * 4);
}

void PaintFlipHorizontal(uint32_t *px, int w, int h) {
    for (int y = 0; y < h; y++) {
        uint32_t *row = px + (size_t)y * w;
        for (int i = 0, j = w - 1; i < j; i++, j--) { uint32_t t = row[i]; row[i] = row[j]; row[j] = t; }
    }
}

void PaintFlipVertical(uint32_t *px, int w, int h) {
    size_t bytes = (size_t)w * 4;
    uint32_t *tmp = malloc(bytes);
    if (!tmp) return;
    for (int i = 0, j = h - 1; i < j; i++, j--) {
        memcpy(tmp, px + (size_t)i * w, bytes);
        memcpy(px + (size_t)i * w, px + (size_t)j * w, bytes);
        memcpy(px + (size_t)j * w, tmp, bytes);
    }
    free(tmp);
}

void PaintRotate90(const uint32_t *src, int w, int h, uint32_t *dst, bool clockwise) {
    for (int y = 0; y < h; y++) {
        const uint32_t *row = src + (size_t)y * w;
        for (int x = 0; x < w; x++) {
            int nx = clockwise ? h - 1 - y : y, ny = clockwise ? x : w - 1 - x;
            dst[(size_t)ny * h + nx] = row[x];
        }
    }
}

void PaintInvert(uint32_t *px, size_t count) {
    for (size_t i = 0; i < count; i++) {
        uint8_t r, g, b, a;
        PaintUnpackRGBA(px[i], &r, &g, &b, &a);
        px[i] = PaintPackRGBA(a - r, a - g, a - b, a);
    }
}

void PaintClearColor(uint32_t *px, size_t count, uint32_t color) {
    for (size_t i = 0; i < count; i++) if (px[i] == color) px[i] = 0;
}
