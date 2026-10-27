#import "Theme.h"

static BOOL dark, highContrast;

static UIColor *Hex(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0
                           green:((rgb >> 8) & 0xff) / 255.0
                            blue:(rgb & 0xff) / 255.0
                           alpha:1];
}

@implementation Theme
+ (void)setDark:(BOOL)d highContrast:(BOOL)h {
    dark = d;
    highContrast = h;
}
+ (BOOL)isDark {
    return dark;
}
+ (UIColor *)background {
    return Hex(dark ? 0x121213 : 0xffffff);
}
+ (UIColor *)text {
    return Hex(dark ? 0xffffff : 0x1a1a1b);
}
+ (UIColor *)secondaryText {
    return Hex(dark ? 0x818384 : 0x787c7e);
}
+ (UIColor *)filledBorder {
    return Hex(dark ? 0x565758 : 0x878a8c);
}
+ (UIColor *)emptyBorder {
    return Hex(dark ? 0x3a3a3c : 0xd3d6da);
}
+ (UIColor *)key {
    return Hex(dark ? 0x818384 : 0xd3d6da);
}
+ (UIColor *)keyText {
    return Hex(dark ? 0xffffff : 0x1a1a1b);
}
+ (UIColor *)backdrop {
    return [UIColor colorWithWhite:dark ? 0 : 1 alpha:0.5];
}
+ (UIColor *)cardBorder {
    return Hex(dark ? 0x1a1a1b : 0xf6f7f8);
}
+ (UIColor *)colorForState:(LetterState)state {
    switch (state) {
    case LetterStateCorrect:
        return Hex(highContrast ? 0xf5793a : dark ? 0x538d4e : 0x6aaa64);
    case LetterStatePresent:
        return Hex(highContrast ? 0x85c0f9 : dark ? 0xb59f3b : 0xc9b458);
    case LetterStateAbsent:
        return Hex(dark ? 0x3a3a3c : 0x787c7e);
    default:
        return [self key];
    }
}
+ (UIFont *)boldFontOfSize:(CGFloat)size {
    return [UIFont fontWithName:@"HelveticaNeue-Bold" size:size];
}
+ (UIFont *)fontOfSize:(CGFloat)size {
    return [UIFont fontWithName:@"HelveticaNeue" size:size];
}
+ (UIFont *)titleFontOfSize:(CGFloat)size {
    // Stand-in for the NYT's Karnak: a heavy serif that ships with iOS 10.
    return [UIFont fontWithName:@"Georgia-Bold" size:size];
}
@end
