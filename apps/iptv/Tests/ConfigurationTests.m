#import <Foundation/Foundation.h>
#import "../Application/Configuration/IPTVConfiguration.h"

int main(void) {
    @autoreleasepool {
        NSString *suite = [@"tv-configuration-tests-" stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[suite stringByAppendingString:@".plist"]];
        [defaults setObject:@"http://192.0.2.2" forKey:@"server.baseURL"];
        NSCAssert(![IPTVConfiguration applyFile:path defaults:defaults], @"Missing profile must preserve existing settings");
        [@{@"gateway.baseURL":@" http://192.0.2.1:9292/ "} writeToFile:path atomically:YES];
        NSCAssert([IPTVConfiguration applyFile:path defaults:defaults], @"Valid profile must apply");
        NSCAssert([[defaults stringForKey:@"gateway.baseURL"] isEqual:@"http://192.0.2.1:9292"], @"Normalize address");
        NSCAssert([[defaults stringForKey:@"server.baseURL"] isEqual:@"http://192.0.2.2"], @"Preserve omitted settings");
        for (id invalid in @[@"file:///tmp/test", @"http://user:pass@192.0.2.1", @"http://192.0.2.1?q=secret", @42, @""]) {
            [@{@"gateway.baseURL":@"http://192.0.2.3", @"server.baseURL":invalid} writeToFile:path atomically:YES];
            NSCAssert(![IPTVConfiguration applyFile:path defaults:defaults], @"Reject invalid profile atomically");
            NSCAssert([[defaults stringForKey:@"gateway.baseURL"] isEqual:@"http://192.0.2.1:9292"], @"Invalid profile must not partially apply");
        }
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        [defaults removePersistentDomainForName:suite];
        puts("Configuration checks passed");
    }
    return 0;
}
