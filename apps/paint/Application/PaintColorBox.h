#import "XPChrome.h"

// The color box along the bottom: current colors, the palette, and Edit Colors.
@interface PaintColorBox : XPPanel
@property(nonatomic, copy) NSArray<UIColor *> *colors;
@property(nonatomic, strong) UIColor *primary, *secondary;
@property(nonatomic, copy) void (^onPick)(NSUInteger index, BOOL secondary);
@property(nonatomic, copy) void (^onSwap)(void);
@property(nonatomic, copy) void (^onEdit)(void);
- (void)reload;
@end

NSString *PaintColorName(UIColor *color);
