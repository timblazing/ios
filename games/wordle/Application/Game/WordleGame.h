#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LetterState) {
    LetterStateNone = 0,
    LetterStateAbsent,
    LetterStatePresent,
    LetterStateCorrect,
};

extern const NSUInteger WordleMaxGuesses;

// One round of Wordle. Words are five uppercase ASCII letters.
@interface WordleGame : NSObject
@property(nonatomic, readonly, copy) NSString *answer;
@property(nonatomic, readonly) NSArray<NSString *> *guesses;
@property(nonatomic, readonly) BOOL won, lost, over;
+ (BOOL)isWellFormed:(NSString *)word;
+ (NSArray<NSNumber *> *)evaluateGuess:(NSString *)guess answer:(NSString *)answer;
// Returns nil if the answer is malformed. Guesses that aren't well formed, or follow a finished game, are dropped.
- (instancetype)initWithAnswer:(NSString *)answer guesses:(NSArray<NSString *> *)guesses;
- (NSArray<NSNumber *> *)evaluationForRow:(NSUInteger)row;
// Hard mode: nil if the guess uses every revealed hint, otherwise the message to show.
- (NSString *)hardModeViolationForGuess:(NSString *)guess;
- (BOOL)addGuess:(NSString *)guess;
// Best state seen so far for each letter, keyed by the single-letter string.
- (NSDictionary<NSString *, NSNumber *> *)keyStates;
@end
