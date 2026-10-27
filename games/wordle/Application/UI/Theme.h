#import "../Game/WordleGame.h"
#import <UIKit/UIKit.h>

// Wordle's palette: light and dark themes, and the high-contrast orange and blue.
@interface Theme : NSObject
+ (void)setDark:(BOOL)dark highContrast:(BOOL)highContrast;
+ (BOOL)isDark;
+ (UIColor *)background;
+ (UIColor *)text;          // tone 1
+ (UIColor *)secondaryText; // tone 2
+ (UIColor *)filledBorder;  // tone 3
+ (UIColor *)emptyBorder;   // tone 4, also dividers
+ (UIColor *)key;
+ (UIColor *)keyText;
+ (UIColor *)backdrop;
+ (UIColor *)cardBorder;
+ (UIColor *)colorForState:(LetterState)state;
+ (UIFont *)boldFontOfSize:(CGFloat)size;
+ (UIFont *)fontOfSize:(CGFloat)size;
+ (UIFont *)titleFontOfSize:(CGFloat)size;
@end
