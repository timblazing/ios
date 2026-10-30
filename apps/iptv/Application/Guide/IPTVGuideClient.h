#import "IPTVGuide.h"

// Use on the main thread. Cancellation keeps the last valid guide and route.
@interface IPTVGuideClient : NSObject
@property(nonatomic, strong, readonly) IPTVGuide *guide;
@property(nonatomic, copy, readonly) NSString *baseURL;
- (void)reloadBaseURLs:(NSArray<NSString *> *)bases completion:(void (^)(BOOL success))completion;
- (void)cancel;
@end
