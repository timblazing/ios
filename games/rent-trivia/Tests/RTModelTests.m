#import <Foundation/Foundation.h>
#import "../Application/Game/RTRound.h"
#import "../Application/Game/RTMovieStream.h"

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { fprintf(stderr, "FAIL %s:%d %s\n", __FILE__, __LINE__, #cond); failures++; } } while (0)

static NSArray<RTQuestion *> *bank(NSUInteger n) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i < n; i++)
        [out addObject:[[RTQuestion alloc] initWithDictionary:@{@"q": [NSString stringWithFormat:@"Q%lu", (unsigned long)i],
                                                                @"a": @[@"right", @"w1", @"w2", @"w3"], @"fact": @"f"}]];
    return out;
}

int main(void) {
    @autoreleasepool {
        // Bundled question bank parses, every question has four distinct answers, and every image exists.
        NSString *dir = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
        NSString *res = [dir stringByAppendingPathComponent:@"../Resources"];
        NSArray *qs = [RTQuestion questionsFromJSONData:[NSData dataWithContentsOfFile:[res stringByAppendingPathComponent:@"Questions.json"]]];
        CHECK(qs.count >= 60);
        BOOL haveMedia = [[NSFileManager defaultManager] fileExistsAtPath:[res stringByAppendingPathComponent:@"Media"]];
        for (RTQuestion *q in qs) {
            CHECK(q.answers.count == 4 && [NSSet setWithArray:q.answers].count == 4);
            CHECK(q.fact.length > 0);
            for (NSString *img in haveMedia ? @[q.image ?: @"", q.backdrop ?: @""] : @[]) {
                if (!img.length) continue;
                NSString *file = [img hasPrefix:@"cast/"] ? [@"cast-" stringByAppendingString:[img substringFromIndex:5]]
                                                          : [@"still-" stringByAppendingString:img];
                NSString *path = [res stringByAppendingFormat:@"/Media/%@.jpg", file];
                if (![[NSFileManager defaultManager] fileExistsAtPath:path]) { fprintf(stderr, "missing %s\n", path.UTF8String); failures++; }
            }
        }
        CHECK([RTQuestion questionsFromJSONData:[NSData data]].count == 0);

        // Round picks distinct questions and tracks the correct answer through the shuffle.
        RTRound *r = [[RTRound alloc] initWithQuestions:bank(30) count:10 random:nil];
        CHECK(r.count == 10);
        NSMutableSet *seen = [NSMutableSet set];
        NSUInteger expected = 0;
        do {
            [seen addObject:r.question.text];
            CHECK([r.answers[r.correctIndex] isEqualToString:@"right"]);
            BOOL pickRight = r.index % 3 != 0;
            CHECK([r answer:pickRight ? r.correctIndex : (r.correctIndex + 1) % 4] == pickRight);
            CHECK(r.isAnswered);
            CHECK(![r answer:r.correctIndex]);  // second tap ignored
            if (pickRight) expected++;
        } while ([r advance]);
        CHECK(seen.count == 10);
        CHECK(r.isFinished && r.correctCount == expected);
        CHECK(![r advance]);

        // Round size is capped by the bank.
        CHECK([[RTRound alloc] initWithQuestions:bank(3) count:10 random:nil].count == 3);

        // Streaks.
        RTRound *s = [[RTRound alloc] initWithQuestions:bank(5) count:5 random:nil];
        [s answer:s.correctIndex]; [s advance];
        [s answer:s.correctIndex]; [s advance];
        [s answer:(s.correctIndex + 1) % 4]; [s advance];
        [s answer:s.correctIndex];
        CHECK(s.streak == 1 && s.bestStreak == 2);

        // Minutes and titles.
        CHECK([RTRound minutesForCorrect:10 of:10] == 525600);
        CHECK([RTRound minutesForCorrect:5 of:10] == 262800);
        CHECK([RTRound minutesForCorrect:0 of:0] == 0);
        CHECK([[RTRound titleForCorrect:10 of:10] isEqualToString:@"NO DAY BUT TODAY"]);
        CHECK([[RTRound titleForCorrect:0 of:10] isEqualToString:@"WILL I?"]);

        // Movie stream.
        RTMovieStream *m = [[RTMovieStream alloc] initWithServer:@"https://example.com/" itemId:@"abc" apiKey:@"KEY"];
        NSString *url = m.playlistURL.absoluteString;
        CHECK([url hasPrefix:@"https://example.com/Videos/abc/master.m3u8?"]);
        CHECK([url containsString:@"VideoCodec=h264"] && [url containsString:@"MaxAudioChannels=2"]);
        CHECK([url containsString:m.playSessionId]);
        CHECK(![url containsString:@"KEY"]);  // the token travels in the header only
        CHECK([m.headers[@"Authorization"] containsString:@"Token=\"KEY\""]);
        CHECK([m.stopURL.absoluteString containsString:@"PlaySessionId="]);
        CHECK(![m.playSessionId isEqualToString:[[RTMovieStream alloc] initWithServer:@"https://x" itemId:@"a" apiKey:@"k"].playSessionId]);
        CHECK([[RTMovieStream formatTime:3734] isEqualToString:@"1:02:14"]);
        CHECK([[RTMovieStream formatTime:245] isEqualToString:@"4:05"]);
        CHECK(![RTMovieStream shouldOfferResumeAt:30 duration:8100]);
        CHECK([RTMovieStream shouldOfferResumeAt:3734 duration:8100]);
        CHECK(![RTMovieStream shouldOfferResumeAt:8000 duration:8100]);
        CHECK([RTMovieStream shouldOfferResumeAt:120 duration:0]);
    }
    if (failures) { fprintf(stderr, "%d failure(s)\n", failures); return 1; }
    printf("All model tests passed.\n");
    return 0;
}
