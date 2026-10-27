#import <UIKit/UIKit.h>

@interface T3PairingScanner : UIViewController
// Completion runs once on the main thread. A nil payload means cancellation.
- (instancetype)initWithCompletion:(void (^)(NSString *payload))completion;
@end
