#import <Foundation/Foundation.h>

// Answers come from the New York Times' public Wordle endpoint, one small JSON file per date, so no
// word list ships with the app. Every answer fetched is cached, and upcoming days are prefetched so the
// daily puzzle still works for a couple of weeks without Wi-Fi.
@interface WordSource : NSObject
+ (instancetype)shared;
- (NSString *)cachedSolutionForDay:(NSInteger)day;
// Completion runs on the main queue with nil on failure.
- (void)solutionForDay:(NSInteger)day completion:(void (^)(NSString *word))completion;
- (void)prefetchFromDay:(NSInteger)day count:(NSInteger)count;
// A random earlier puzzle for practice. Falls back to cached past answers when offline; day is -1 if
// nothing is available.
- (void)randomDayBefore:(NSInteger)today
              excluding:(NSInteger)excluded
             completion:(void (^)(NSInteger day, NSString *word))completion;
// Past answers are always accepted as guesses, even if the dictionary doesn't know them.
- (BOOL)isKnownAnswer:(NSString *)word;
@end
