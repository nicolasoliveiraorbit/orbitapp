//
//  OrbitLog.h
//  Orbit
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OrbitLog : NSObject

+ (void)log:(NSString *)message;
+ (void)error:(NSString *)message;
+ (void)warn:(NSString *)message;
+ (NSString *)logFilePath;

@end

NS_ASSUME_NONNULL_END
