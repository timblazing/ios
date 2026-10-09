#import "CardNode.h"
#import <UIKit/UIKit.h>
@implementation CardNode
- (instancetype)initWithCard:(Card *)card size:(CGSize)size {
    if ((self = [super initWithColor:[UIColor clearColor] size:size])) {
        _card = card;
        self.name = @"card";
    }
    return self;
}
+ (NSString *)artNameForIdentifier:(NSInteger)identifier {
    if (identifier < 0)
        return @"back";
    Card *card = [[Card alloc] initWithIdentifier:identifier];
    return [NSString stringWithFormat:@"%@%@", card.rankText, @[ @"H", @"D", @"C", @"S" ][card.suit]];
}
+ (UIImage *)artNamed:(NSString *)name {
    NSString *path = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Cards"]
        stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
    UIImage *art = [UIImage imageWithContentsOfFile:path];
    return art && art.size.width > 0 && art.size.height > 0 ? art : nil;
}
+ (NSCache *)cache {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        // 52 faces + back at both orientations' sizes, with headroom for other screen sizes.
        cache.countLimit = 220;
    });
    return cache;
}
+ (NSString *)keyForCard:(Card *)card size:(CGSize)size {
    return [NSString stringWithFormat:@"%ld-%.0f-%.0f", (long)(card.faceUp ? card.identifier : -1),
                                      size.width, size.height];
}
+ (void)preloadForSizes:(NSArray<NSValue *> *)sizes {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<NSString *> *missing = [NSMutableArray array];
        for (NSInteger i = -1; i < 52; i++)
            if (![self artNamed:[self artNameForIdentifier:i]])
                [missing addObject:[self artNameForIdentifier:i]];
        if (missing.count)
            NSLog(@"Solitaire: no card art for %@; using drawn fallback", [missing componentsJoinedByString:@" "]);
        NSMutableDictionary<NSString *, UIImage *> *images = [NSMutableDictionary dictionary];
        for (NSValue *value in sizes)
            for (NSInteger i = -1; i < 52; i++) {
                Card *card = [[Card alloc] initWithIdentifier:MAX(i, 0)];
                card.faceUp = i >= 0;
                NSString *key = [self keyForCard:card size:value.CGSizeValue];
                if (!images[key] && ![[self cache] objectForKey:key])
                    images[key] = [self imageForCard:card size:value.CGSizeValue];
            }
        dispatch_async(dispatch_get_main_queue(), ^{
            [images enumerateKeysAndObjectsUsingBlock:^(NSString *key, UIImage *image, BOOL *stop) {
                if (![[self cache] objectForKey:key])
                    [[self cache] setObject:[SKTexture textureWithImage:image] forKey:key];
            }];
        });
    });
}
// Draws the v1 card back: a slate field with a diagonal lattice and an inset hairline.
+ (void)drawFallbackBackInRect:(CGRect)rect {
    [[UIColor colorWithRed:0.11 green:0.16 blue:0.23 alpha:1] setFill];
    UIRectFill(rect);
    CGFloat spacing = rect.size.width * 32 / 240;
    UIBezierPath *lattice = [UIBezierPath bezierPath];
    for (CGFloat d = -rect.size.height; d < rect.size.width + rect.size.height; d += spacing) {
        [lattice moveToPoint:CGPointMake(CGRectGetMinX(rect) + d, CGRectGetMinY(rect))];
        [lattice addLineToPoint:CGPointMake(CGRectGetMinX(rect) + d + rect.size.height, CGRectGetMaxY(rect))];
        [lattice moveToPoint:CGPointMake(CGRectGetMinX(rect) + d + rect.size.height, CGRectGetMinY(rect))];
        [lattice addLineToPoint:CGPointMake(CGRectGetMinX(rect) + d, CGRectGetMaxY(rect))];
    }
    lattice.lineWidth = 1;
    [[UIColor colorWithRed:0.26 green:0.34 blue:0.43 alpha:1] setStroke];
    [lattice stroke];
    [[UIColor colorWithWhite:1 alpha:0.18] setStroke];
    UIBezierPath *border = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 5, 5) cornerRadius:4];
    border.lineWidth = 1;
    [border stroke];
}
+ (void)drawFallbackFaceForCard:(Card *)card size:(CGSize)size {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *ink = card.red ? [UIColor colorWithRed:0.69 green:0.19 blue:0.25 alpha:1]
                            : [UIColor colorWithWhite:0.12 alpha:1];
    NSDictionary *corner = @{
        NSFontAttributeName : [UIFont systemFontOfSize:size.width * 0.19 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName : ink
    };
    NSString *label = [NSString stringWithFormat:@"%@%@", card.rankText, card.suitText];
    [label drawAtPoint:CGPointMake(8, 6) withAttributes:corner];
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, size.width, size.height);
    CGContextRotateCTM(ctx, M_PI);
    [label drawAtPoint:CGPointMake(8, 6) withAttributes:corner];
    CGContextRestoreGState(ctx);
    NSDictionary *center = @{
        NSFontAttributeName : [UIFont systemFontOfSize:size.width * 0.45],
        NSForegroundColorAttributeName : ink
    };
    CGSize symbol = [card.suitText sizeWithAttributes:center];
    [card.suitText drawAtPoint:CGPointMake((size.width - symbol.width) / 2, (size.height - symbol.height) / 2)
                withAttributes:center];
}
+ (UIImage *)imageForCard:(Card *)card size:(CGSize)size {
    // Cap to 2x; a complete face set stays comfortably small on the A7.
    UIGraphicsBeginImageContextWithOptions(size, NO, MIN(2, [UIScreen mainScreen].scale));
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectInset((CGRect){CGPointZero, size}, 2, 2);
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:7];
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 0.5), 2, [UIColor colorWithWhite:0 alpha:0.55].CGColor);
    [[UIColor colorWithWhite:0.93 alpha:1] setFill];
    [shape fill];
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    [shape addClip];
    UIImage *art = [self artNamed:[self artNameForIdentifier:card.faceUp ? card.identifier : -1]];
    if (art) {
        // Aspect-fill, centered. Art is authored at 5:7, so nothing is cropped in practice.
        CGFloat scale = MAX(rect.size.width / art.size.width, rect.size.height / art.size.height);
        CGSize target = CGSizeMake(art.size.width * scale, art.size.height * scale);
        [art drawInRect:CGRectMake(CGRectGetMidX(rect) - target.width / 2,
                                   CGRectGetMidY(rect) - target.height / 2, target.width, target.height)];
    } else if (card.faceUp)
        [self drawFallbackFaceForCard:card size:size];
    else
        [self drawFallbackBackInRect:rect];
    CGContextRestoreGState(ctx);
    // A hairline edge, so the top of each card in an overlapping column reads against the one beneath.
    UIBezierPath *edge = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 0.25, 0.25) cornerRadius:7];
    edge.lineWidth = 0.5;
    [[UIColor colorWithRed:0.09 green:0.07 blue:0.12 alpha:0.45] setStroke];
    [edge stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
+ (SKTexture *)textureForCard:(Card *)card size:(CGSize)size {
    NSString *key = [self keyForCard:card size:size];
    SKTexture *texture = [[self cache] objectForKey:key];
    if (!texture) {
        texture = [SKTexture textureWithImage:[self imageForCard:card size:size]];
        [[self cache] setObject:texture forKey:key];
    }
    return texture;
}
- (void)refreshWithSize:(CGSize)size animated:(BOOL)animated {
    SKTexture *next = [CardNode textureForCard:self.card size:size];
    self.size = size;
    if (animated && self.texture && self.texture != next) {
        [self removeActionForKey:@"flip"];
        self.xScale = 1;
        SKAction *close = [SKAction scaleXTo:0 duration:0.07];
        SKAction *open = [SKAction scaleXTo:1 duration:0.09];
        [self runAction:[SKAction sequence:@[
                  close, [SKAction runBlock:^{
                      self.texture = next;
                  }],
                  open
              ]]
                withKey:@"flip"];
    } else {
        [self removeActionForKey:@"flip"];
        self.xScale = 1;
        self.texture = next;
    }
}
@end
