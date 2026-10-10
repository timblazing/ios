#import <Foundation/Foundation.h>
#import "RTQuestion.h"

typedef uint32_t (^RTRandom)(uint32_t upperBound);

extern const NSInteger RTMinutesInAYear;

// A round: a random pick of questions, each with its answers shuffled.
@interface RTRound : NSObject
@property(nonatomic, readonly) NSUInteger count;
@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, readonly) NSUInteger correctCount;
@property(nonatomic, readonly) NSUInteger streak;
@property(nonatomic, readonly) NSUInteger bestStreak;
@property(nonatomic, readonly, getter=isAnswered) BOOL answered;
@property(nonatomic, readonly, getter=isFinished) BOOL finished;
@property(nonatomic, readonly) RTQuestion *question;
@property(nonatomic, readonly) NSArray<NSString *> *answers;  // shuffled
@property(nonatomic, readonly) NSUInteger correctIndex;

- (instancetype)initWithQuestions:(NSArray<RTQuestion *> *)questions count:(NSUInteger)count random:(RTRandom)random;
// The question after this one, for preloading its images; nil on the last.
- (RTQuestion *)nextQuestion;
// Records an answer for the current question. Returns whether it was right. Ignored once answered.
- (BOOL)answer:(NSUInteger)choice;
// Moves to the next question. Returns NO when the round is over.
- (BOOL)advance;
// Score as a share of 525,600 minutes.
- (NSInteger)minutes;
+ (NSInteger)minutesForCorrect:(NSUInteger)correct of:(NSUInteger)count;
+ (NSString *)titleForCorrect:(NSUInteger)correct of:(NSUInteger)count;
+ (NSString *)blurbForCorrect:(NSUInteger)correct of:(NSUInteger)count;
@end
