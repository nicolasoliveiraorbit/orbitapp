//
//  LlamaBridge.h
//  Orbit
//
//  Created by Ehron on 12/07/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LlamaBridge : NSObject

+ (nullable instancetype)loadModelAtPath:(NSString *)modelPath
                                    error:(NSError * _Nullable * _Nullable)error;

- (nullable NSString *)generateWithPrompt:(NSString *)prompt
                                maxTokens:(NSInteger)maxTokens
                                temperature:(double)temperature
                                       topP:(double)topP
                                       topK:(NSInteger)topK
                          repetitionPenalty:(double)repetitionPenalty
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError * _Nullable * _Nullable)error;

- (void)unload;

@property (nonatomic, readonly) BOOL isModelLoaded;
@property (nonatomic, readonly, copy) NSString *backendMode;
@property (nonatomic, readonly, copy) NSString *backendDeviceSummary;
@property (nonatomic, readonly) NSInteger gpuLayerCount;

@end

NS_ASSUME_NONNULL_END
