#import <UIKit/UIKit.h>

@interface RTResultsViewController : UIViewController
- (instancetype)initWithCorrect:(NSUInteger)correct of:(NSUInteger)count bestStreak:(NSUInteger)bestStreak results:(NSArray<NSNumber *> *)results;
@end
