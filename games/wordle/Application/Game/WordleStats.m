#import "WordleStats.h"

@implementation WordleStats {
    NSInteger _streak, _lastWonDay, _lastRecordedDay;
    NSMutableArray<NSNumber *> *_distribution;
}
- (instancetype)initWithDictionary:(NSDictionary *)d {
    if (!(self = [super init]))
        return nil;
    _played = [d[@"played"] integerValue];
    _wins = [d[@"wins"] integerValue];
    _streak = [d[@"streak"] integerValue];
    _maxStreak = [d[@"maxStreak"] integerValue];
    _lastWonDay = d[@"lastWonDay"] ? [d[@"lastWonDay"] integerValue] : NSIntegerMin;
    _lastRecordedDay = d[@"lastRecordedDay"] ? [d[@"lastRecordedDay"] integerValue] : NSIntegerMin;
    _distribution = [NSMutableArray arrayWithArray:@[ @0, @0, @0, @0, @0, @0 ]];
    NSArray *saved = d[@"distribution"];
    if ([saved isKindOfClass:[NSArray class]] && saved.count == 6)
        for (NSUInteger i = 0; i < 6; i++)
            _distribution[i] = @([saved[i] integerValue]);
    return self;
}
- (instancetype)init {
    return [self initWithDictionary:@{}];
}
- (NSDictionary *)dictionary {
    NSMutableDictionary *d = [@{
        @"played" : @(_played),
        @"wins" : @(_wins),
        @"streak" : @(_streak),
        @"maxStreak" : @(_maxStreak),
        @"distribution" : [_distribution copy]
    } mutableCopy];
    if (_lastWonDay != NSIntegerMin)
        d[@"lastWonDay"] = @(_lastWonDay);
    if (_lastRecordedDay != NSIntegerMin)
        d[@"lastRecordedDay"] = @(_lastRecordedDay);
    return d;
}
- (NSArray<NSNumber *> *)distribution {
    return [_distribution copy];
}
- (void)recordDay:(NSInteger)day won:(BOOL)won guesses:(NSInteger)guesses {
    if (_lastRecordedDay != NSIntegerMin && day <= _lastRecordedDay)
        return;
    _lastRecordedDay = day;
    _played++;
    if (!won) {
        _streak = 0;
        return;
    }
    _wins++;
    _streak = _lastWonDay != NSIntegerMin && _lastWonDay == day - 1 ? _streak + 1 : 1;
    _lastWonDay = day;
    _maxStreak = MAX(_maxStreak, _streak);
    if (guesses >= 1 && guesses <= 6)
        _distribution[guesses - 1] = @(_distribution[guesses - 1].integerValue + 1);
}
- (NSInteger)currentStreakOnDay:(NSInteger)today {
    return _lastWonDay != NSIntegerMin && _lastWonDay >= today - 1 ? _streak : 0;
}
- (NSInteger)winPercent {
    return _played ? (NSInteger)llround(100.0 * _wins / _played) : 0;
}
@end
