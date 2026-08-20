//
//  WhisperBridge.h
//  Orbit
//
//  Created by Ehron on 08/07/26.
//


//
//  WhisperBridge.h
//  Orbit
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WhisperBridge : NSObject

/// Transcreve um arquivo de áudio utilizando o modelo Whisper.
///
/// @param audioPath Caminho absoluto do arquivo WAV.
/// @param modelPath Caminho absoluto do modelo ggml-base.bin.
/// @param language Código do idioma (ex.: "pt").
/// @param error Mensagem de erro caso a transcrição falhe.
/// @return Texto transcrito ou nil em caso de erro.
+ (nullable NSString *)transcribeAudioAtPath:(NSString *)audioPath
                                   modelPath:(NSString *)modelPath
                                    language:(NSString *)language
                                    progress:(nullable void (^)(NSInteger progress))progress
                                       error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
