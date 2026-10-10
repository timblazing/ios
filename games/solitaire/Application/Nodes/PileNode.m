#import "PileNode.h"
@implementation PileNode
- (instancetype)initWithSize:(CGSize)size label:(NSString *)label {
    if ((self = [super init])) {
        CGPathRef path = CGPathCreateWithRoundedRect(
            CGRectMake(-size.width / 2 + 2, -size.height / 2 + 2, size.width - 4, size.height - 4), 7, 7,
            NULL);
        self.path = path;
        CGPathRelease(path);
        [self setHighlighted:NO];
        // Empty foundations and columns show a faint A or K for what goes there; the stock shows the recycle arrow.
        BOOL arrow = [label isEqualToString:@"↻"];
        SKLabelNode *text = [SKLabelNode labelNodeWithFontNamed:arrow ? @"HelveticaNeue-Light" : @"AvenirNextCondensed-DemiBold"];
        text.text = label;
        text.fontSize = arrow ? 26 : size.width * 0.36;
        text.fontColor = [SKColor colorWithWhite:1 alpha:arrow ? 0.6 : 0.28];
        text.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
        [self addChild:text];
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted {
    self.zPosition = highlighted ? 800 : 0;
    self.fillColor = highlighted ? [SKColor clearColor] : [SKColor colorWithWhite:0 alpha:0.12];
    for (SKNode *child in self.children)
        child.hidden = highlighted;
    // Legal drops glow gold against the felt.
    self.strokeColor = highlighted ? [SKColor colorWithRed:1 green:0.82 blue:0.25 alpha:1]
                                   : [SKColor colorWithWhite:1 alpha:0.4];
    self.glowWidth = highlighted ? 2 : 0;
    self.lineWidth = highlighted ? 3 : 1.5;
}
@end
