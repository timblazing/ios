#import "WordleGame.h"

const NSUInteger WordleMaxGuesses = 6;

@implementation WordleGame {
    NSMutableArray<NSString *> *_guesses;
}
+ (BOOL)isWellFormed:(NSString *)word {
    if (word.length != 5)
        return NO;
    for (NSUInteger i = 0; i < 5; i++) {
        unichar c = [word characterAtIndex:i];
        if (c < 'A' || c > 'Z')
            return NO;
    }
    return YES;
}
+ (NSArray<NSNumber *> *)evaluateGuess:(NSString *)guess answer:(NSString *)answer {
    unichar g[5], a[5];
    [guess getCharacters:g range:NSMakeRange(0, 5)];
    [answer getCharacters:a range:NSMakeRange(0, 5)];
    // Exact matches first; the answer's leftover letters then go to presents left to right, so a
    // repeated guess letter is only yellow as many times as the answer still has it.
    NSInteger left[26] = {0};
    LetterState s[5];
    for (int i = 0; i < 5; i++) {
        s[i] = g[i] == a[i] ? LetterStateCorrect : LetterStateAbsent;
        if (s[i] != LetterStateCorrect)
            left[a[i] - 'A']++;
    }
    for (int i = 0; i < 5; i++)
        if (s[i] != LetterStateCorrect && left[g[i] - 'A'] > 0) {
            s[i] = LetterStatePresent;
            left[g[i] - 'A']--;
        }
    return @[ @(s[0]), @(s[1]), @(s[2]), @(s[3]), @(s[4]) ];
}
- (instancetype)initWithAnswer:(NSString *)answer guesses:(NSArray<NSString *> *)guesses {
    if (![WordleGame isWellFormed:answer] || !(self = [super init]))
        return nil;
    _answer = [answer copy];
    _guesses = [NSMutableArray array];
    for (id guess in guesses)
        if ([guess isKindOfClass:[NSString class]])
            [self addGuess:guess];
    return self;
}
- (NSArray<NSString *> *)guesses {
    return [_guesses copy];
}
- (BOOL)won {
    return [_guesses.lastObject isEqualToString:_answer];
}
- (BOOL)lost {
    return !self.won && _guesses.count >= WordleMaxGuesses;
}
- (BOOL)over {
    return self.won || self.lost;
}
- (BOOL)addGuess:(NSString *)guess {
    if (self.over || ![WordleGame isWellFormed:guess])
        return NO;
    [_guesses addObject:[guess copy]];
    return YES;
}
- (NSArray<NSNumber *> *)evaluationForRow:(NSUInteger)row {
    return row < _guesses.count ? [WordleGame evaluateGuess:_guesses[row] answer:_answer] : nil;
}
- (NSString *)hardModeViolationForGuess:(NSString *)guess {
    static NSString *const ordinals[] = {@"1st", @"2nd", @"3rd", @"4th", @"5th"};
    NSInteger required[26] = {0};
    for (NSUInteger row = 0; row < _guesses.count; row++) {
        NSString *previous = _guesses[row];
        NSArray<NSNumber *> *eval = [self evaluationForRow:row];
        NSInteger seen[26] = {0};
        for (NSUInteger i = 0; i < 5; i++) {
            unichar c = [previous characterAtIndex:i];
            LetterState state = eval[i].integerValue;
            if (state == LetterStateCorrect && [guess characterAtIndex:i] != c)
                return [NSString stringWithFormat:@"%@ letter must be %C", ordinals[i], c];
            if (state != LetterStateAbsent)
                seen[c - 'A']++;
        }
        for (int c = 0; c < 26; c++)
            required[c] = MAX(required[c], seen[c]);
    }
    NSInteger have[26] = {0};
    for (NSUInteger i = 0; i < 5; i++)
        have[[guess characterAtIndex:i] - 'A']++;
    // Report in the order the letters appear in the latest guess, like the original.
    NSString *latest = _guesses.lastObject;
    for (NSUInteger i = 0; i < latest.length; i++) {
        unichar c = [latest characterAtIndex:i];
        if (have[c - 'A'] < required[c - 'A'])
            return [NSString stringWithFormat:@"Guess must contain %C", c];
    }
    for (int c = 0; c < 26; c++)
        if (have[c] < required[c])
            return [NSString stringWithFormat:@"Guess must contain %C", (unichar)('A' + c)];
    return nil;
}
- (NSDictionary<NSString *, NSNumber *> *)keyStates {
    NSMutableDictionary *states = [NSMutableDictionary dictionary];
    for (NSUInteger row = 0; row < _guesses.count; row++) {
        NSArray<NSNumber *> *eval = [self evaluationForRow:row];
        for (NSUInteger i = 0; i < 5; i++) {
            NSString *letter = [_guesses[row] substringWithRange:NSMakeRange(i, 1)];
            if ([states[letter] integerValue] < eval[i].integerValue)
                states[letter] = eval[i];
        }
    }
    return states;
}
@end
