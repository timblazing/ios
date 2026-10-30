#import <Foundation/Foundation.h>

@interface IPTVConfiguration : NSObject
+ (BOOL)applyFile:(NSString *)path defaults:(NSUserDefaults *)defaults;
@end
