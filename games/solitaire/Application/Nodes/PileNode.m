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
        text.fontColor = [SKColor colorWithWhite:1 alpha:arrow ? 0.32 : 0.1];
        text.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
        [self addChild:text];
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted {
    self.zPosition = highlighted ? 800 : 0;
    self.fillColor = highlighted ? [SKColor clearColor] : [SKColor colorWithWhite:1 alpha:0.035];
    for (SKNode *child in self.children)
        child.hidden = highlighted;
    // Legal drops glow in the card back's gold.
    self.strokeColor = highlighted ? [SKColor colorWithRed:0.937 green:0.788 blue:0.396 alpha:1]
                                   : [SKColor colorWithWhite:1 alpha:0.14];
    self.glowWidth = highlighted ? 2 : 0;
    self.lineWidth = highlighted ? 2.5 : 1;
}
@end
