#import "PaintOptionsView.h"

@implementation PaintOptionGroup
+ (instancetype)groupWithCount:(NSInteger)count columns:(NSInteger)columns {
    PaintOptionGroup *group = [self new];
    group.count = count;
    group.columns = columns;
    return group;
}
@end

@interface PaintOptionCell : UIControl
@property(nonatomic, weak) PaintOptionGroup *group;
@property(nonatomic) NSInteger index;
@end

@implementation PaintOptionCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.isAccessibilityElement = YES; }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; [self setNeedsDisplay]; }
- (BOOL)isOn { return self.group.isSelected && self.group.isSelected(self.index); }
- (UIAccessibilityTraits)accessibilityTraits { return UIAccessibilityTraitButton | ([self isOn] ? UIAccessibilityTraitSelected : 0); }
- (NSString *)accessibilityLabel { return self.group.label ? self.group.label(self.index) : nil; }
- (void)drawRect:(CGRect)rect {
    BOOL on = [self isOn];
    if (on || self.highlighted) {
        [(on ? XPSelectionColor() : XPColor(0xC1D2EE)) setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 1, 1) cornerRadius:3] fill];
    }
    if (self.group.draw) self.group.draw(self.index, CGRectInset(self.bounds, 4, 3), on ? UIColor.whiteColor : UIColor.blackColor);
}
@end

@implementation PaintOptionsView {
    NSMutableArray<PaintOptionCell *> *_cells;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.sunken = YES; _cells = [NSMutableArray array]; }
    return self;
}
- (void)setGroups:(NSArray<PaintOptionGroup *> *)groups {
    _groups = [groups copy];
    for (UIView *cell in _cells) [cell removeFromSuperview];
    [_cells removeAllObjects];
    for (PaintOptionGroup *group in groups) {
        for (NSInteger i = 0; i < group.count; i++) {
            PaintOptionCell *cell = [PaintOptionCell new];
            cell.group = group;
            cell.index = i;
            [cell addTarget:self action:@selector(cellTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:cell];
            [_cells addObject:cell];
        }
    }
    [self setNeedsLayout];
}
- (void)cellTapped:(PaintOptionCell *)cell { if (cell.group.select) cell.group.select(cell.index); [self refresh]; }
- (void)refresh { for (UIView *cell in _cells) [cell setNeedsDisplay]; }
// Rows share whatever height the box has, up to a comfortable 40pt.
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat pad = 4, gap = 8, width = self.bounds.size.width - pad * 2;
    NSInteger rows = 0;
    for (PaintOptionGroup *group in self.groups) rows += (group.count + group.columns - 1) / group.columns;
    if (!rows) return;
    CGFloat rowH = floor(MIN(40, (self.bounds.size.height - pad * 2 - gap * (self.groups.count - 1)) / rows)), y = pad;
    NSUInteger c = 0;
    for (PaintOptionGroup *group in self.groups) {
        CGFloat cellW = floor(width / group.columns);
        for (NSInteger i = 0; i < group.count; i++, c++) _cells[c].frame = CGRectMake(pad + (i % group.columns) * cellW, y + (i / group.columns) * rowH, cellW, rowH);
        y += ((group.count + group.columns - 1) / group.columns) * rowH + gap;
    }
}
@end
