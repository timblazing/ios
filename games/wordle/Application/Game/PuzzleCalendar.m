#import "PuzzleCalendar.h"

@implementation PuzzleCalendar
+ (NSCalendar *)calendar {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone localTimeZone];
    return calendar;
}
+ (NSDate *)launchInCalendar:(NSCalendar *)calendar {
    NSDateComponents *c = [NSDateComponents new];
    c.year = 2021;
    c.month = 6;
    c.day = 19;
    c.hour = 12; // noon keeps day arithmetic clear of DST changes
    return [calendar dateFromComponents:c];
}
+ (NSInteger)dayForDate:(NSDate *)date {
    NSCalendar *calendar = [self calendar];
    NSDate *launch = [calendar startOfDayForDate:[self launchInCalendar:calendar]];
    return [calendar components:NSCalendarUnitDay
                       fromDate:launch
                         toDate:[calendar startOfDayForDate:date]
                        options:0]
        .day;
}
+ (NSDate *)dateForDay:(NSInteger)day {
    NSCalendar *calendar = [self calendar];
    return [calendar dateByAddingUnit:NSCalendarUnitDay
                                value:day
                               toDate:[self launchInCalendar:calendar]
                              options:0];
}
+ (NSString *)keyForDay:(NSInteger)day {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.calendar = [self calendar];
    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:[self dateForDay:day]];
}
+ (NSTimeInterval)secondsUntilNextDayFrom:(NSDate *)date {
    NSCalendar *calendar = [self calendar];
    NSDate *next = [calendar dateByAddingUnit:NSCalendarUnitDay
                                        value:1
                                       toDate:[calendar startOfDayForDate:date]
                                      options:0];
    return MAX(0, [next timeIntervalSinceDate:date]);
}
@end
