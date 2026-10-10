#import "GameScene.h"
#import "../Nodes/CardNode.h"
#import "../Nodes/PileNode.h"
@interface GameScene ()
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, CardNode *> *cards;
@property(nonatomic, strong) NSMutableArray<PileNode *> *slots;
@property(nonatomic) CGSize cardSize;
@property(nonatomic) NSInteger selectedPile;
@property(nonatomic) NSInteger selectedIndex;
@property(nonatomic) CGPoint touchStart;
@property(nonatomic) BOOL dragging;
@property(nonatomic, strong) NSArray<CardNode *> *lifted;
@property(nonatomic, strong) NSArray<NSValue *> *origins;
@property(nonatomic, strong) UITouch *activeTouch;
@property(nonatomic, strong) SKSpriteNode *background;
@property(nonatomic) BOOL autoPlaying;
@property(nonatomic) BOOL celebrating;
@property(nonatomic, strong) NSArray<CardNode *> *previewDancers;
@property(nonatomic) BOOL previewing;
@end
@implementation GameScene
- (instancetype)initWithSize:(CGSize)size {
    if ((self = [super initWithSize:size])) {
        self.backgroundColor = [SKColor colorWithRed:0.035 green:0.22 blue:0.09 alpha:1];
        self.scaleMode = SKSceneScaleModeResizeFill;
        _cards = [NSMutableDictionary dictionary];
        _slots = [NSMutableArray array];
        _selectedPile = -1;
        _background = [SKSpriteNode node];
        _background.anchorPoint = CGPointZero;
        _background.zPosition = -10;
        [self addChild:_background];
    }
    return self;
}
+ (CGFloat)marginForWidth:(CGFloat)width {
    return MAX(14, width * 0.025);
}
// Card size depends on scene width only, so it is known for both orientations up front.
+ (CGSize)cardSizeForWidth:(CGFloat)width {
    CGFloat w = MIN(112, (width - 2 * [self marginForWidth:width] - 6 * 12) / 7);
    return CGSizeMake(w, w * 1.4);
}
- (CGFloat)margin {
    return [GameScene marginForWidth:self.size.width];
}
// Portrait has far more vertical room, so face-up cards in a column are spread further apart.
- (CGFloat)faceUpStep {
    return self.size.height > self.size.width ? 0.32 : 0.24;
}
// Leaves room above the top row so the stock and foundations aren't a stretch to reach.
- (CGFloat)topRowY {
    return self.size.height - MAX(20, self.size.height * 0.06) - self.cardSize.height / 2;
}
- (CGFloat)gap {
    return (self.size.width - 2 * self.margin - 7 * self.cardSize.width) / 6;
}
- (CGPoint)originForPile:(NSInteger)p {
    CGFloat step = self.cardSize.width + self.gap, x = self.margin + self.cardSize.width / 2;
    // Foundations on the left, waste then stock on the right.
    if (p < 6)
        return CGPointMake(x + (p == 0 ? 6 : p == 1 ? 5 : p - 2) * step, self.topRowY);
    return CGPointMake(x + (p - 6) * step, self.topRowY - self.cardSize.height - 24);
}
- (CGPoint)positionForPile:(NSInteger)p index:(NSInteger)i {
    CGPoint pos = [self originForPile:p];
    if (p >= 6) {
        NSArray *pile = self.game.piles[p];
        CGFloat desired = 0;
        for (NSInteger j = 0; j < (NSInteger)pile.count - 1; j++)
            desired += self.cardSize.height * (((Card *)pile[j]).faceUp ? self.faceUpStep : 0.105);
        CGFloat room = MAX(0, pos.y - self.cardSize.height / 2 - 12 - self.bottomInset),
                factor = desired > 0 ? MIN(1, room / desired) : 1;
        for (NSInteger j = 0; j < i; j++)
            pos.y -= self.cardSize.height * (((Card *)pile[j]).faceUp ? self.faceUpStep : 0.105) * factor;
    }
    return pos;
}
- (void)preloadTextures {
    CGSize screen = [UIScreen mainScreen].bounds.size;
    CGFloat longSide = MAX(screen.width, screen.height), shortSide = MIN(screen.width, screen.height);
    [CardNode preloadForSizes:@[
        [NSValue valueWithCGSize:[GameScene cardSizeForWidth:longSide]],
        [NSValue valueWithCGSize:[GameScene cardSizeForWidth:shortSide]]
    ]];
}
// Card-table felt: a lighter pool of green from the top edge, darkening toward the corners, like the icon.
+ (SKTexture *)backgroundTextureForSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {0.2, 0.56, 0.29, 1, 0.1, 0.4, 0.19, 1, 0.035, 0.22, 0.09, 1},
            locations[] = {0, 0.55, 1};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, 3);
    CGPoint top = CGPointMake(size.width / 2, -size.height * 0.1);
    CGContextDrawRadialGradient(UIGraphicsGetCurrentContext(), gradient, top, 0, top,
                                hypot(size.width, size.height) * 0.85, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [SKTexture textureWithImage:image];
}
- (void)didChangeSize:(CGSize)oldSize {
    if (self.game) {
        [self cancelInteraction];
        [self refreshAnimated:NO];
    }
}
- (void)refreshAnimated:(BOOL)animated {
    if (!self.game)
        return;
    self.cardSize = [GameScene cardSizeForWidth:self.size.width];
    if (!CGSizeEqualToSize(self.background.size, self.size)) {
        self.background.texture = [GameScene backgroundTextureForSize:self.size];
        self.background.size = self.size;
    }
    for (SKNode *s in self.slots)
        [s removeFromParent];
    [self.slots removeAllObjects];
    for (NSInteger p = 0; p < 13; p++) {
        PileNode *slot = [[PileNode alloc] initWithSize:self.cardSize label:@[ @"↻", @"", @"", @"K" ][MIN(p, 6) == 6 ? 3 : MIN(p, 2)]];
        slot.position = [self originForPile:p];
        [self.slots addObject:slot];
        [self addChild:slot];
    }
    BOOL motion = animated && !UIAccessibilityIsReduceMotionEnabled();
    for (NSInteger p = 0; p < 13; p++)
        for (NSInteger i = 0; i < (NSInteger)self.game.piles[p].count; i++) {
            Card *card = self.game.piles[p][i];
            CardNode *node = self.cards[@(card.identifier)];
            if (!node) {
                node = [[CardNode alloc] initWithCard:card size:self.cardSize];
                node.position = [self originForPile:0];
                self.cards[@(card.identifier)] = node;
                [self addChild:node];
            }
            node.card = card;
            node.pile = p;
            node.index = i;
            node.zPosition = 10 + p * 52 + i;
            node.colorBlendFactor = 0;
            node.alpha = 1;
            // The card under the top stays visible, so a pile never looks empty while a card flies onto it.
            node.hidden = p < 6 && i < (NSInteger)self.game.piles[p].count - 2;
            [node refreshWithSize:self.cardSize animated:motion];
            [node removeActionForKey:@"move"];
            [node removeActionForKey:@"victory"];
            [node setScale:1];
            node.zRotation = 0;
            CGPoint target = [self positionForPile:p index:i];
            if (motion) {
                SKAction *move = [SKAction moveTo:target duration:0.18];
                move.timingMode = SKActionTimingEaseOut;
                [node runAction:move withKey:@"move"];
            } else
                node.position = target;
        }
    [self showSelection];
    self.celebrating = self.celebrating && self.game.won;
    if (self.celebrating)
        [self danceAnimated:!UIAccessibilityIsReduceMotionEnabled()];
    if (self.previewDancers)
        [self dance:self.previewDancers animated:!UIAccessibilityIsReduceMotionEnabled()];
}
- (CardNode *)cardAt:(CGPoint)point {
    CardNode *best = nil;
    for (SKNode *node in [self nodesAtPoint:point])
        if ([node isKindOfClass:[CardNode class]] && !node.hidden &&
            (!best || node.zPosition > best.zPosition))
            best = (CardNode *)node;
    return best;
}
- (NSInteger)pileAt:(CGPoint)point {
    if (point.y > [self originForPile:6].y + self.cardSize.height / 2 + 10) {
        for (NSInteger p = 0; p < 6; p++)
            if (CGRectContainsPoint(CGRectInset(self.slots[p].frame, -8, -8), point))
                return p;
        return -1;
    }
    for (NSInteger p = 6; p < 13; p++)
        if (fabs(point.x - [self originForPile:p].x) < (self.cardSize.width + self.gap) / 2)
            return p;
    return -1;
}
- (void)showSelection {
    for (NSInteger p = 0; p < (NSInteger)self.slots.count; p++) {
        BOOL legal = self.selectedPile >= 0 && [self.game canMoveFrom:self.selectedPile index:self.selectedIndex to:p];
        [self.slots[p] setHighlighted:legal];
        // Outline the card a stack would land on, not the empty slot under the column.
        NSInteger count = self.game.piles[p].count;
        self.slots[p].position = legal && p >= 6 && count ? [self positionForPile:p index:count - 1]
                                                          : [self originForPile:p];
    }
    for (CardNode *node in self.cards.allValues) {
        node.color = [SKColor colorWithRed:1 green:0.75 blue:0.1 alpha:1];
        node.colorBlendFactor =
            (node.pile == self.selectedPile && node.index >= self.selectedIndex) ? 0.22 : 0;
    }
}
- (void)cancelInteraction {
    [self removeActionForKey:@"autoWin"];
    self.autoPlaying = NO;
    self.activeTouch = nil;
    self.dragging = NO;
    self.lifted = nil;
    self.origins = nil;
    self.selectedPile = -1;
    [self showSelection];
}
- (void)changed {
    [self cancelInteraction];
    [self refreshAnimated:YES];
    if (self.gameChanged)
        self.gameChanged();
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.previewing) {
        [self endPreview];
        if (self.previewEnded)
            self.previewEnded();
        return;
    }
    if (self.game.won || self.activeTouch || self.autoPlaying)
        return;
    UITouch *touch = touches.anyObject;
    self.activeTouch = touch;
    self.touchStart = [touch locationInNode:self];
    self.dragging = NO;
    CardNode *node = [self cardAt:self.touchStart];
    if (node && [self.game canLiftFrom:node.pile index:node.index]) {
        NSMutableArray *lifted = [NSMutableArray array], *origins = [NSMutableArray array];
        for (NSInteger i = node.index; i < (NSInteger)self.game.piles[node.pile].count; i++) {
            CardNode *n = self.cards[@(self.game.piles[node.pile][i].identifier)];
            [n removeActionForKey:@"move"];
            [lifted addObject:n];
            [origins addObject:[NSValue valueWithCGPoint:n.position]];
        }
        self.lifted = lifted;
        self.origins = origins;
    }
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.activeTouch || ![touches containsObject:self.activeTouch] || !self.lifted.count)
        return;
    CGPoint point = [self.activeTouch locationInNode:self];
    CGFloat dx = point.x - self.touchStart.x, dy = point.y - self.touchStart.y;
    if (!self.dragging && hypot(dx, dy) < 7)
        return;
    self.dragging = YES;
    CardNode *first = self.lifted.firstObject;
    self.selectedPile = first.pile;
    self.selectedIndex = first.index;
    [self showSelection];
    for (NSUInteger i = 0; i < self.lifted.count; i++) {
        CardNode *n = self.lifted[i];
        CGPoint origin = [self.origins[i] CGPointValue];
        n.position = CGPointMake(origin.x + dx, origin.y + dy);
        n.zPosition = 1000 + i;
    }
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.activeTouch || ![touches containsObject:self.activeTouch])
        return;
    CGPoint point = [self.activeTouch locationInNode:self];
    self.activeTouch = nil;
    NSInteger destination = [self pileAt:point];
    if (self.dragging) {
        [self.game moveFrom:self.selectedPile index:self.selectedIndex to:destination];
        [self changed];
        return;
    }
    self.lifted = nil;
    self.origins = nil;
    if (hypot(point.x - self.touchStart.x, point.y - self.touchStart.y) > 12) {
        [self changed];
        return;
    }
    if (destination == 0) {
        [self.game draw];
        [self changed];
        return;
    }
    CardNode *node = [self cardAt:point];
    if (!node || ![self.game canLiftFrom:node.pile index:node.index])
        return;
    NSInteger best = [self.game bestDestinationFrom:node.pile index:node.index];
    if (best != NSNotFound) {
        [self.game moveFrom:node.pile index:node.index to:best];
        [self changed];
    } else
        [self shakePile:node.pile index:node.index];
}
// A short sideways nudge says "nowhere to go" without moving anything.
- (void)shakePile:(NSInteger)p index:(NSInteger)index {
    if (UIAccessibilityIsReduceMotionEnabled())
        return;
    for (NSInteger i = index; i < (NSInteger)self.game.piles[p].count; i++) {
        CardNode *n = self.cards[@(self.game.piles[p][i].identifier)];
        CGPoint home = [self positionForPile:p index:i];
        [n removeActionForKey:@"move"];
        n.position = home;
        SKAction *shake = [SKAction sequence:@[
            [SKAction moveByX:-6 y:0 duration:0.04], [SKAction moveByX:12 y:0 duration:0.07],
            [SKAction moveByX:-10 y:0 duration:0.06], [SKAction moveTo:home duration:0.05]
        ]];
        [n runAction:shake withKey:@"move"];
    }
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self cancelInteraction];
    [self refreshAnimated:NO];
}
- (void)autoWin {
    if (self.autoPlaying || !self.game.canAutoWin)
        return;
    [self cancelInteraction];
    self.autoPlaying = YES;
    [self autoWinNext];
}
- (void)autoWinNext {
    BOOL moved = [self.game autoWinStep];
    self.autoPlaying = moved && !self.game.won;
    [self refreshAnimated:YES];
    if (self.gameChanged)
        self.gameChanged();
    if (!self.autoPlaying)
        return;
    __weak typeof(self) weakSelf = self;
    [self runAction:[SKAction sequence:@[
              [SKAction waitForDuration:0.07], [SKAction runBlock:^{
                  [weakSelf autoWinNext];
              }]
          ]]
            withKey:@"autoWin"];
}
- (void)celebrate {
    self.celebrating = YES;
    [self danceAnimated:!UIAccessibilityIsReduceMotionEnabled()];
}
// Kings and queens alternating red and black: K♥ Q♠ K♣ Q♦ K♦ Q♣ K♠ Q♥.
static const NSInteger kDancers[] = {12, 50, 38, 24, 25, 37, 51, 11};
- (void)previewCelebration {
    [self cancelInteraction];
    [self endPreview];
    self.previewing = YES;
    if (self.game.won)
        return;  // the real dancers are already out
    NSMutableArray *dancers = [NSMutableArray array];
    for (NSUInteger i = 0; i < 8; i++) {
        Card *card = [[Card alloc] initWithIdentifier:kDancers[i]];
        card.faceUp = YES;
        CardNode *n = [[CardNode alloc] initWithCard:card size:self.cardSize];
        n.position = [self originForPile:0];
        [self addChild:n];
        [dancers addObject:n];
    }
    self.previewDancers = dancers;
    [self dance:dancers animated:!UIAccessibilityIsReduceMotionEnabled()];
}
- (void)endPreview {
    for (CardNode *n in self.previewDancers)
        [n removeFromParent];
    self.previewDancers = nil;
    self.previewing = NO;
}
// The kings and queens step off the foundations into a chorus line across the lower board and dance.
- (void)danceAnimated:(BOOL)motion {
    NSMutableArray *dancers = [NSMutableArray array];
    for (NSUInteger i = 0; i < 8; i++) {
        Card *c = self.game.piles[2 + kDancers[i] / 13][kDancers[i] % 13];
        [dancers addObject:self.cards[@(c.identifier)]];
        // The jacks stay behind, so the foundations still look complete.
        self.cards[@(((Card *)self.game.piles[2 + kDancers[i] / 13][10]).identifier)].hidden = NO;
    }
    [self dance:dancers animated:motion];
}
// A chorus line across the lower board, each card a beat behind its neighbor.
- (void)dance:(NSArray<CardNode *> *)order animated:(BOOL)motion {
    CGFloat available = self.size.width - 2 * self.margin, spacing = MIN(self.cardSize.width * 1.2, available / order.count),
            scale = MIN(1.1, spacing / (self.cardSize.width * 1.12)),
            y = self.bottomInset + (self.size.height - self.bottomInset) * 0.3;
    for (NSUInteger i = 0; i < order.count; i++) {
        CardNode *n = order[i];
        [n refreshWithSize:self.cardSize animated:NO];
        CGPoint spot = CGPointMake(self.size.width / 2 + (i - (order.count - 1) / 2.0) * spacing, y);
        [n removeActionForKey:@"move"];
        [n removeActionForKey:@"victory"];
        n.hidden = NO;
        n.zPosition = 900 + i;
        if (!motion) {
            n.position = spot;
            [n setScale:scale];
            n.zRotation = 0;
            continue;
        }
        SKAction *enter = [SKAction group:@[ [SKAction moveTo:spot duration:0.5], [SKAction scaleTo:scale duration:0.5] ]];
        enter.timingMode = SKActionTimingEaseInEaseOut;
        SKAction *up = [SKAction moveByX:0 y:34 duration:0.22], *down = [SKAction moveByX:0 y:-34 duration:0.22];
        up.timingMode = SKActionTimingEaseOut;
        down.timingMode = SKActionTimingEaseIn;
        SKAction *hop = [SKAction sequence:@[ up, down ]];
        SKAction *step = [SKAction repeatActionForever:[SKAction sequence:@[
            [SKAction group:@[ hop, [SKAction rotateToAngle:0.24 duration:0.44 shortestUnitArc:YES] ]],
            [SKAction group:@[ hop, [SKAction rotateToAngle:-0.24 duration:0.44 shortestUnitArc:YES] ]]
        ]]];
        [n runAction:[SKAction sequence:@[ [SKAction waitForDuration:0.3 + i * 0.08], enter,
                                           [SKAction waitForDuration:(i % 2) * 0.22], step ]]
             withKey:@"victory"];
    }
}
@end
