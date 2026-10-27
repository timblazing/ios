#import <UIKit/UIKit.h>

// Windows XP "Luna" look, drawn in code: colors, bevels, buttons, windows, message boxes, and menus.
UIColor *XPColor(uint32_t rgb);
UIColor *XPFaceColor(void);       // #ECE9D8 dialog beige
UIColor *XPSelectionColor(void);  // #316AC5 menu highlight
UIFont *XPFont(CGFloat size);
UIFont *XPBoldFont(CGFloat size);
UIFont *XPTitleFont(CGFloat size);
UIImage *PaintIcon(NSString *name);
void XPDrawBevel(CGRect rect, BOOL raised, BOOL thick);
void XPNoAnimation(void (^block)(void));

@interface XPPanel : UIView
@property(nonatomic) BOOL sunken;
@property(nonatomic) BOOL thick;
@end

@interface XPTitleGradientView : UIView
@end

// A Paint toolbox button: raised, or pushed in with a dithered face when selected.
@interface XPToolButton : UIControl
@property(nonatomic, strong) UIImage *icon;
@end

// A Luna push button, as in message boxes.
@interface XPButton : UIControl
@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL isDefault;
+ (instancetype)buttonWithTitle:(NSString *)title target:(id)target action:(SEL)action;
@end

// A flat button that highlights on touch, for the title bar and menu bar.
@interface XPFlatButton : UIControl
@property(nonatomic, strong) UIImage *icon;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, strong) UIColor *highlightColor;
@property(nonatomic) BOOL lit;
@end

@interface XPWindow : UIView
- (instancetype)initWithTitle:(NSString *)title contentSize:(CGSize)size;
@property(nonatomic, readonly) UIView *contentView;
@property(nonatomic, copy) void (^onClose)(void);
- (void)presentInView:(UIView *)host;
- (void)dismiss;
@end

typedef NS_ENUM(NSInteger, XPDialogIcon) { XPDialogIconNone, XPDialogIconInfo, XPDialogIconWarning, XPDialogIconQuestion };

@interface XPDialog : NSObject
// Closing the window picks the last button.
+ (XPWindow *)showInView:(UIView *)host title:(NSString *)title message:(NSString *)message icon:(XPDialogIcon)icon buttons:(NSArray<NSString *> *)buttons handler:(void (^)(NSInteger index))handler;
@end

@interface XPMenuItem : NSObject
@property(nonatomic, copy) NSString *title, *shortcut;
@property(nonatomic) BOOL enabled, checked, separator;
@property(nonatomic, copy) void (^action)(void);
+ (instancetype)item:(NSString *)title shortcut:(NSString *)shortcut action:(void (^)(void))action;
+ (instancetype)item:(NSString *)title shortcut:(NSString *)shortcut enabled:(BOOL)enabled checked:(BOOL)checked action:(void (^)(void))action;
+ (instancetype)separator;
@end

@interface XPMenuView : UIView
- (instancetype)initWithItems:(NSArray<XPMenuItem *> *)items;
@property(nonatomic, copy) void (^onPick)(XPMenuItem *item);
@end
