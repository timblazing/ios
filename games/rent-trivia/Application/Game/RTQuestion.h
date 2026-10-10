#import <Foundation/Foundation.h>

// One trivia question. The first answer in the source data is always the correct one.
@interface RTQuestion : NSObject
@property(nonatomic, copy, readonly) NSString *text;
@property(nonatomic, copy, readonly) NSArray<NSString *> *answers;
@property(nonatomic, copy, readonly) NSString *fact;
@property(nonatomic, copy, readonly) NSString *image;      // shown in a frame beside the question, or nil
@property(nonatomic, copy, readonly) NSString *backdrop;   // full-screen still behind the question, or nil
+ (NSArray<RTQuestion *> *)questionsFromJSONData:(NSData *)data;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end
