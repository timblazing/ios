#import "RTRound.h"

const NSInteger RTMinutesInAYear = 525600;

@implementation RTRound {
    NSArray<RTQuestion *> *_picked;
    RTRandom _random;
}

- (instancetype)initWithQuestions:(NSArray<RTQuestion *> *)questions count:(NSUInteger)count random:(RTRandom)random {
    if ((self = [super init])) {
        _random = random ?: ^uint32_t(uint32_t n) { return arc4random_uniform(n); };
        NSMutableArray *pool = [questions mutableCopy];
        [self shuffle:pool];
        _count = MIN(count, pool.count);
        _picked = [pool subarrayWithRange:NSMakeRange(0, _count)];
        [self prepareQuestion];
    }
    return self;
}

- (void)shuffle:(NSMutableArray *)a {
    for (NSUInteger i = a.count; i > 1; i--) [a exchangeObjectAtIndex:i - 1 withObjectAtIndex:_random((uint32_t)i)];
}

- (void)prepareQuestion {
    _answered = NO;
    if (_index >= _count) {
        _finished = YES;
        _question = nil;
        _answers = @[];
        return;
    }
    _question = _picked[_index];
    NSMutableArray *shuffled = [_question.answers mutableCopy];
    [self shuffle:shuffled];
    _answers = shuffled;
    _correctIndex = [shuffled indexOfObject:_question.answers.firstObject];
}

- (RTQuestion *)nextQuestion { return _index + 1 < _count ? _picked[_index + 1] : nil; }

- (BOOL)answer:(NSUInteger)choice {
    if (_finished || _answered) return NO;
    _answered = YES;
    BOOL right = choice == _correctIndex;
    if (right) {
        _correctCount++;
        _streak++;
        _bestStreak = MAX(_bestStreak, _streak);
    } else {
        _streak = 0;
    }
    return right;
}

- (BOOL)advance {
    if (_finished) return NO;
    _index++;
    [self prepareQuestion];
    return !_finished;
}

- (NSInteger)minutes { return [RTRound minutesForCorrect:_correctCount of:_count]; }

+ (NSInteger)minutesForCorrect:(NSUInteger)correct of:(NSUInteger)count {
    if (count == 0) return 0;
    return (NSInteger)llround((double)RTMinutesInAYear * correct / count);
}

+ (NSString *)titleForCorrect:(NSUInteger)correct of:(NSUInteger)count {
    double p = count ? (double)correct / count : 0;
    if (p >= 1) return @"NO DAY BUT TODAY";
    if (p >= 0.8) return @"LA VIE BOHÈME";
    if (p >= 0.6) return @"OUT TONIGHT";
    if (p >= 0.4) return @"ANOTHER DAY";
    return @"WILL I?";
}

+ (NSString *)blurbForCorrect:(NSUInteger)correct of:(NSUInteger)count {
    double p = count ? (double)correct / count : 0;
    if (p >= 1) return @"A perfect year. Every last minute. Jonathan Larson would be proud.";
    if (p >= 0.8) return @"You'd have a seat at the Life Café any night of the week.";
    if (p >= 0.6) return @"Strong showing. Light a candle and go again.";
    if (p >= 0.4) return @"Not bad. Put the movie on and try it again.";
    return @"Time for a rewatch. Measure in love.";
}
@end
