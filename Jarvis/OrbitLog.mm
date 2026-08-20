//
//  OrbitLog.mm
//  Orbit
//

#import "OrbitLog.h"
#import "Orbit-Bridge-Header.h"

@implementation OrbitLog

+ (NSString *)logDirectory {
    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *logsDir = [docs[0] stringByAppendingPathComponent:@"Orbit/Logs"];
    [[NSFileManager defaultManager] createDirectoryAtPath:logsDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return logsDir;
}

+ (NSString *)logFilePath {
    return [[self logDirectory] stringByAppendingPathComponent:@"orbit_debug.log"];
}

+ (void)log:(NSString *)message {
    [self writeLevel:@"INFO" message:message];
}

+ (void)error:(NSString *)message {
    [self writeLevel:@"ERROR" message:message];
}

+ (void)warn:(NSString *)message {
    [self writeLevel:@"WARN" message:message];
}

+ (void)writeLevel:(NSString *)level message:(NSString *)message {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *ts = [fmt stringFromDate:[NSDate date]];
    NSString *entry = [NSString stringWithFormat:@"[%@] [%@] %@\n", ts, level, message];

    NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:[self logFilePath]];

    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:data];
        [fh closeFile];
    } else {
        [data writeToFile:[self logFilePath] atomically:YES];
    }
}

@end
