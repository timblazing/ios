#import <Foundation/Foundation.h>

// Puzzle numbers count local calendar days from Wordle's launch, 19 June 2021 (puzzle 0).
@interface PuzzleCalendar : NSObject
+ (NSInteger)dayForDate:(NSDate *)date;
+ (NSDate *)dateForDay:(NSInteger)day;
+ (NSString *)keyForDay:(NSInteger)day; // yyyy-MM-dd
+ (NSTimeInterval)secondsUntilNextDayFrom:(NSDate *)date;
@end
