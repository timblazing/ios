#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IPTVTeam : NSObject
@property(nonatomic, copy, readonly) NSString *abbr;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *nick;
@property(nonatomic, copy, readonly) NSString *color;
@property(nonatomic, copy, readonly) NSString *logo;
@property(nonatomic, copy, readonly) NSString *record;
@property(nonatomic, copy, readonly) NSString *score;
@end

@interface IPTVGuideChannel : NSObject
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, strong, readonly) NSURL *stream;
@property(nonatomic, copy, readonly) NSString *logo;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, NSString *> *> *epg;
@end

@interface IPTVGame : NSObject
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, strong, readonly) NSDate *start;
@property(nonatomic, copy, readonly) NSString *state;
@property(nonatomic, copy, readonly) NSString *detail;
@property(nonatomic, copy, readonly) NSString *tv;
@property(nonatomic, strong, readonly) IPTVTeam *away;
@property(nonatomic, strong, readonly) IPTVTeam *home;
@property(nonatomic, copy, readonly) NSArray<IPTVGuideChannel *> *channels;
@end

@interface IPTVLeague : NSObject
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSArray<IPTVGame *> *games;
@property(nonatomic, copy, readonly) NSArray<IPTVGuideChannel *> *channels;
@end

@interface IPTVGuide : NSObject
@property(nonatomic, strong, readonly, nullable) NSDate *updated;
@property(nonatomic, copy, readonly) NSArray<IPTVLeague *> *leagues;
- (nullable instancetype)initWithData:(NSData *)data error:(NSError *_Nullable *_Nullable)error;
+ (nullable NSDate *)dateFromString:(id)value;
@end

NS_ASSUME_NONNULL_END
