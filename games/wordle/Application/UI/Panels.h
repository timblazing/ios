#import "../Game/WordleStats.h"
#import "Panel.h"

@interface HelpPanel : Panel
- (instancetype)init;
@end

@interface SettingsPanel : Panel
// Return NO to refuse the change; the switch flips back.
@property(nonatomic, copy) BOOL (^onChange)(NSString *key, BOOL on);
- (instancetype)initWithValues:(NSDictionary<NSString *, NSNumber *> *)values; // hardMode, darkTheme, highContrast
@end

@interface StatsPanel : Panel
@property(nonatomic, copy) void (^onShare)(void);
@property(nonatomic, copy) void (^onNewPractice)(void);
// highlightRow is the winning row to color (0-5) or -1.
- (instancetype)initWithStats:(WordleStats *)stats
                        today:(NSInteger)today
                 highlightRow:(NSInteger)highlightRow
                     gameOver:(BOOL)gameOver
                     practice:(BOOL)practice;
@end

@interface MenuPanel : Panel
- (instancetype)initWithToday:(NSInteger)today practice:(BOOL)practice practiceDay:(NSInteger)practiceDay;
@property(nonatomic, copy) void (^onDaily)(void);
@property(nonatomic, copy) void (^onPractice)(void);
@property(nonatomic, copy) void (^onNewPractice)(void);
@end

NSString *PuzzleNumber(NSInteger day);
