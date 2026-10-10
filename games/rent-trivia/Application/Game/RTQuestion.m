#import "RTQuestion.h"

@implementation RTQuestion
+ (NSArray<RTQuestion *> *)questionsFromJSONData:(NSData *)data {
    id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (![json isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (id item in json) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        RTQuestion *q = [[RTQuestion alloc] initWithDictionary:item];
        if (q) [out addObject:q];
    }
    return out;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    NSString *text = dict[@"q"];
    NSArray *answers = dict[@"a"];
    if (![text isKindOfClass:[NSString class]] || ![answers isKindOfClass:[NSArray class]] || answers.count < 2) return nil;
    if ((self = [super init])) {
        _text = [text copy];
        _answers = [answers copy];
        _fact = [dict[@"fact"] isKindOfClass:[NSString class]] ? dict[@"fact"] : @"";
        _image = [dict[@"img"] isKindOfClass:[NSString class]] ? dict[@"img"] : nil;
        _backdrop = [dict[@"bg"] isKindOfClass:[NSString class]] ? dict[@"bg"] : nil;
    }
    return self;
}
@end
