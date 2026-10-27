#import <Foundation/Foundation.h>

// Daily-puzzle statistics. Days are puzzle numbers (see PuzzleCalendar).
@interface WordleStats : NSObject
@property(nonatomic, readonly) NSInteger played, wins, maxStreak;
@property(nonatomic, readonly) NSArray<NSNumber *> *distribution; // wins by guess count, 1 through 6
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionary;
// Ignores a day that's already been recorded.
- (void)recordDay:(NSInteger)day won:(BOOL)won guesses:(NSInteger)guesses;
// The streak as of today: a missed day breaks it even before the next game is played.
- (NSInteger)currentStreakOnDay:(NSInteger)today;
- (NSInteger)winPercent;
@end
