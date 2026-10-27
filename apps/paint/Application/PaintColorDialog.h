#import "XPChrome.h"

// XP's Edit Colors dialog: basic colors, a hue/saturation field, and a luminosity bar.
@interface PaintColorDialog : NSObject
+ (void)showInView:(UIView *)host color:(UIColor *)color completion:(void (^)(UIColor *color))completion;
@end
