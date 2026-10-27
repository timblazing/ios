#import <UIKit/UIKit.h>

// The poster's look: four colour bands, white stencil type, typewritten paper.
@interface RTStyle : NSObject
+ (UIColor *)orange;
+ (UIColor *)blue;
+ (UIColor *)green;
+ (UIColor *)red;
+ (UIColor *)yellow;
+ (UIColor *)paper;
+ (UIColor *)ink;
+ (UIColor *)bandColor:(NSUInteger)index;  // orange, blue, green, red, repeating
+ (UIFont *)stencil:(CGFloat)size;          // Futura Condensed ExtraBold
+ (UIFont *)type:(CGFloat)size;             // American Typewriter
+ (UIFont *)typeBold:(CGFloat)size;
+ (NSAttributedString *)spaced:(NSString *)text font:(UIFont *)font color:(UIColor *)color kern:(CGFloat)kern;
+ (BOOL)reduceMotion;

// Media: "snow" -> still-snow.jpg, "cast/mark" -> cast-mark.jpg.
+ (UIImage *)imageNamed:(NSString *)name;
// Decodes on a background queue so the first draw doesn't hitch, then calls back on the main queue.
+ (void)loadImageNamed:(NSString *)name completion:(void (^)(UIImage *image))completion;
+ (UIImage *)logo;
@end

// A full-screen still, aspect-filled, with a dark wash so type reads on top.
@interface RTBackdropView : UIView
@property(nonatomic, strong, readonly) UIImageView *imageView;
@property(nonatomic) CGFloat dim;
- (void)showImageNamed:(NSString *)name animated:(BOOL)animated;
- (void)startDrift;  // a slow Ken Burns zoom, skipped with Reduce Motion
@end

// A colour-band tile with white stencil type, slightly askew like a pasted-up poster.
@interface RTTileButton : UIButton
@property(nonatomic, strong) UIColor *tileColor;
@property(nonatomic) CGFloat tilt;  // radians
+ (instancetype)tileWithTitle:(NSString *)title color:(UIColor *)color;
@end

// Typewritten paper with two strips of tape across the top.
@interface RTPaperView : UIView
@end

// A white-bordered snapshot with a shadow.
@interface RTPolaroidView : UIView
@property(nonatomic, strong, readonly) UIImageView *imageView;
@end

// Positions a view by bounds and center so it works while the view is rotated.
static inline void RTPlace(UIView *view, CGRect rect) {
    view.bounds = (CGRect){CGPointZero, rect.size};
    view.center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

// Swaps the window's root screen with a crossfade.
void RTShowScreen(UIViewController *controller);
