#import "../Application/Game/PuzzleCalendar.h"
#import "../Application/Game/WordleGame.h"
#import "../Application/Game/WordleStats.h"
#import <Foundation/Foundation.h>
#include <stdlib.h>

static NSUInteger assertions = 0;
#define CHECK(...)                                                                                           \
    do {                                                                                                     \
        assertions++;                                                                                        \
        if (!(__VA_ARGS__)) {                                                                                \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #__VA_ARGS__);                           \
            exit(1);                                                                                         \
        }                                                                                                    \
    } while (0)

// C = correct, P = present, . = absent
static NSString *Pattern(NSString *guess, NSString *answer) {
    NSMutableString *s = [NSMutableString string];
    for (NSNumber *n in [WordleGame evaluateGuess:guess answer:answer])
        [s appendString:n.integerValue == LetterStateCorrect   ? @"C"
                        : n.integerValue == LetterStatePresent ? @"P"
                                                               : @"."];
    return s;
}

static void Evaluation(void) {
    CHECK([Pattern(@"CIGAR", @"CIGAR") isEqualToString:@"CCCCC"]);
    CHECK([Pattern(@"WEARY", @"WRUNG") isEqualToString:@"C..P."]);
    CHECK([Pattern(@"KEBAB", @"ABBEY") isEqualToString:@".PCPP"]);
    CHECK([Pattern(@"BABES", @"ABBEY") isEqualToString:@"PPCC."]);
    // A repeated letter is yellow only as often as the answer has it unmatched.
    CHECK([Pattern(@"EERIE", @"LEVER") isEqualToString:@"PCP.."]);
    CHECK([Pattern(@"SPEED", @"ABIDE") isEqualToString:@"..P.P"]);
    CHECK([Pattern(@"LLAMA", @"HELLO") isEqualToString:@"PP..."]);
    CHECK([Pattern(@"ALLEY", @"HELLO") isEqualToString:@".PCP."]);
}

static void Game(void) {
    CHECK([[WordleGame alloc] initWithAnswer:@"major" guesses:@[]] == nil);
    CHECK([[WordleGame alloc] initWithAnswer:@"MAJ0R" guesses:@[]] == nil);
    WordleGame *game = [[WordleGame alloc] initWithAnswer:@"MAJOR" guesses:@[ @"CRANE", @"bad", (NSString *)@42 ]];
    CHECK(game.guesses.count == 1 && !game.over);
    CHECK(![game addGuess:@"ABCD"]);
    CHECK([game addGuess:@"MAJOR"] && game.won && game.over && !game.lost);
    CHECK(![game addGuess:@"CRANE"]);
    WordleGame *lost =
        [[WordleGame alloc] initWithAnswer:@"MAJOR"
                                   guesses:@[ @"CRANE", @"SLATE", @"PIOUS", @"DOUBT", @"FIGHT", @"WHELK" ]];
    CHECK(lost.lost && lost.over && !lost.won && lost.guesses.count == 6);
    NSDictionary *keys = [[[WordleGame alloc] initWithAnswer:@"MAJOR" guesses:@[ @"ROAMS", @"MANOR" ]] keyStates];
    CHECK([keys[@"M"] integerValue] == LetterStateCorrect); // present first, correct later: best wins
    CHECK([keys[@"R"] integerValue] == LetterStateCorrect);
    CHECK([keys[@"S"] integerValue] == LetterStateAbsent);
    CHECK(keys[@"Z"] == nil);
}

static void HardMode(void) {
    WordleGame *game = [[WordleGame alloc] initWithAnswer:@"MAJOR" guesses:@[]];
    CHECK([game hardModeViolationForGuess:@"QUICK"] == nil);
    [game addGuess:@"MANOR"]; // M A correct, N absent, O R correct
    CHECK([[game hardModeViolationForGuess:@"QUICK"] isEqualToString:@"1st letter must be M"]);
    CHECK([[game hardModeViolationForGuess:@"MXNOR"] isEqualToString:@"2nd letter must be A"]);
    CHECK([game hardModeViolationForGuess:@"MAYOR"] == nil);
    WordleGame *present = [[WordleGame alloc] initWithAnswer:@"MAJOR" guesses:@[ @"ROAST" ]];
    CHECK([[present hardModeViolationForGuess:@"CLIMB"] isEqualToString:@"Guess must contain R"]);
    CHECK([[present hardModeViolationForGuess:@"RIVAL"] isEqualToString:@"Guess must contain O"]);
    CHECK([present hardModeViolationForGuess:@"ARBOR"] == nil);
    // Two yellow E's mean the next guess needs two E's.
    WordleGame *twice = [[WordleGame alloc] initWithAnswer:@"STEEP" guesses:@[ @"EERIE" ]];
    CHECK([twice hardModeViolationForGuess:@"LEVEL"] == nil);
    CHECK([[twice hardModeViolationForGuess:@"LEAFY"] isEqualToString:@"Guess must contain E"]);
}

static void Stats(void) {
    WordleStats *stats = [WordleStats new];
    CHECK(stats.played == 0 && [stats winPercent] == 0 && [stats currentStreakOnDay:10] == 0);
    [stats recordDay:10 won:YES guesses:3];
    [stats recordDay:10 won:NO guesses:6]; // same day twice is ignored
    [stats recordDay:11 won:YES guesses:4];
    CHECK(stats.played == 2 && stats.wins == 2 && [stats currentStreakOnDay:11] == 2);
    CHECK([stats currentStreakOnDay:12] == 2 && [stats currentStreakOnDay:13] == 0);
    [stats recordDay:13 won:YES guesses:4]; // a gap restarts the streak
    CHECK([stats currentStreakOnDay:13] == 1 && stats.maxStreak == 2);
    [stats recordDay:14 won:NO guesses:6];
    CHECK([stats currentStreakOnDay:14] == 0 && stats.played == 4 && [stats winPercent] == 75);
    CHECK([stats.distribution isEqualToArray:(@[ @0, @0, @1, @2, @0, @0 ])]);
    WordleStats *copy = [[WordleStats alloc] initWithDictionary:[stats dictionary]];
    CHECK([[copy dictionary] isEqualToDictionary:[stats dictionary]]);
    [copy recordDay:12 won:YES guesses:1];
    CHECK(copy.played == 4);
}

static void Calendar(void) {
    CHECK([[PuzzleCalendar keyForDay:0] isEqualToString:@"2021-06-19"]);
    CHECK([[PuzzleCalendar keyForDay:255] isEqualToString:@"2022-03-01"]);
    CHECK([[PuzzleCalendar keyForDay:1938] isEqualToString:@"2026-10-09"]);
    for (NSInteger day = 0; day < 2500; day += 7)
        CHECK([PuzzleCalendar dayForDate:[PuzzleCalendar dateForDay:day]] == day);
    NSDate *date = [PuzzleCalendar dateForDay:1938];
    NSTimeInterval left = [PuzzleCalendar secondsUntilNextDayFrom:date];
    CHECK(left > 0 && left <= 86400 + 3600);
    CHECK([PuzzleCalendar dayForDate:[date dateByAddingTimeInterval:left]] == 1939);
}

int main(void) {
    @autoreleasepool {
        Evaluation();
        Game();
        HardMode();
        Stats();
        Calendar();
        printf("OK: %lu assertions\n", (unsigned long)assertions);
    }
    return 0;
}
