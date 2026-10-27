#import "XPChrome.h"

// One block of choices in the tool options box. Each cell draws its own preview.
@interface PaintOptionGroup : NSObject
@property(nonatomic) NSInteger count, columns;
@property(nonatomic, copy) void (^draw)(NSInteger index, CGRect rect, UIColor *ink);
@property(nonatomic, copy) BOOL (^isSelected)(NSInteger index);
@property(nonatomic, copy) void (^select)(NSInteger index);
@property(nonatomic, copy) NSString *(^label)(NSInteger index);
+ (instancetype)groupWithCount:(NSInteger)count columns:(NSInteger)columns;
@end

@interface PaintOptionsView : XPPanel
@property(nonatomic, copy) NSArray<PaintOptionGroup *> *groups;
- (void)refresh;
@end
