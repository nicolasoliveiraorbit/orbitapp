

//
//  WhisperBridge.mm
//  Orbit
//

#import "WhisperBridge.h"

#include "whisper.h"
#include <vector>
#include <cstdint>

@implementation WhisperBridge

+ (nullable NSString *)transcribeAudioAtPath:(NSString *)audioPath
                                   modelPath:(NSString *)modelPath
                                    language:(NSString *)language
                                    progress:(nullable void (^)(NSInteger progress))progress
                                       error:(NSError * _Nullable * _Nullable)error {
    if (audioPath.length == 0 || modelPath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"WhisperBridge"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Caminho do áudio ou do modelo está vazio."}];
        }
        return nil;
    }

    const char *model_path = [modelPath UTF8String];
    const char *language_code = language.length > 0 ? [language UTF8String] : "pt";

    struct whisper_context_params contextParams = whisper_context_default_params();
    struct whisper_context *context = whisper_init_from_file_with_params(model_path, contextParams);

    if (context == nullptr) {
        if (error) {
            *error = [NSError errorWithDomain:@"WhisperBridge"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Falha ao carregar o modelo Whisper."}];
        }
        return nil;
    }

    NSError *audioError = nil;
    NSData *audioData = [NSData dataWithContentsOfFile:audioPath options:0 error:&audioError];

    if (audioData == nil ||    audioData.length <= 44) {
        whisper_free(context);

        if (error) {
            *error = [NSError errorWithDomain:@"WhisperBridge"
                                         code:-3
                                     userInfo:@{NSLocalizedDescriptionKey: audioError.localizedDescription ?: @"Falha ao ler o arquivo WAV."}];
        }
        return nil;
    }

    const uint8_t *bytes = (const uint8_t *)audioData.bytes;
    const NSUInteger length = audioData.length;

    NSUInteger dataOffset = 0;
    NSUInteger pcmDataSize = 0;

    if (length >= 12 &&
        memcmp(bytes, "RIFF", 4) == 0 &&
        memcmp(bytes + 8, "WAVE", 4) == 0) {
        NSUInteger pos = 12;
        while (pos + 8 <= length) {
            char chunkId[5] = {};
            memcpy(chunkId, bytes + pos, 4);
            uint32_t chunkSize = 0;
            memcpy(&chunkSize, bytes + pos + 4, sizeof(uint32_t));

            if (memcmp(chunkId, "data", 4) == 0) {
                dataOffset = pos + 8;
                pcmDataSize = MIN((NSUInteger)chunkSize, length - dataOffset);
                break;
            }

            pos += 8 + chunkSize;
            if (chunkSize % 2 != 0) { pos += 1; }
        }
    }

    if (dataOffset == 0 || dataOffset >= length || pcmDataSize < 2) {
        whisper_free(context);
        if (error) {
            *error = [NSError errorWithDomain:@"WhisperBridge"
                                         code:-3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Falha ao localizar dados PCM no WAV."}];
        }
        return nil;
    }

    const NSUInteger sampleCount = pcmDataSize / sizeof(int16_t);
    const int16_t *pcm16 = (const int16_t *)(bytes + dataOffset);
    std::vector<float> pcmf32;
    pcmf32.reserve(sampleCount);

    for (NSUInteger index = 0; index < sampleCount; index++) {
        pcmf32.push_back((float)pcm16[index] / 32768.0f);
    }

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = false;
    params.print_progress = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.translate = false;
    params.language = language_code;
    params.n_threads = MAX(1, (int)[[NSProcessInfo processInfo] processorCount] - 2);

    struct ProgressCallbackContext {
        void (^block)(NSInteger);
    };

    ProgressCallbackContext progressContext = {
        progress ? [progress copy] : nil
    };

    params.progress_callback = [](
        struct whisper_context *,
        struct whisper_state *,
        int progressValue,
        void *userData
    ) {
        auto *callbackContext =
            static_cast<ProgressCallbackContext *>(userData);

        if (callbackContext == nullptr || callbackContext->block == nil) {
            return;
        }

        NSInteger clampedProgress =
            MAX(0, MIN(100, progressValue));

        void (^progressBlock)(NSInteger) = callbackContext->block;

        dispatch_async(dispatch_get_main_queue(), ^{
            progressBlock(clampedProgress);
        });
    };

    params.progress_callback_user_data = &progressContext;

    const int result = whisper_full(
        context,
        params,
        pcmf32.data(),
        (int)pcmf32.size()
    );

    progressContext.block = nil;

    if (result != 0) {
        whisper_free(context);

        if (error) {
            *error = [NSError errorWithDomain:@"WhisperBridge"
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: @"Falha ao executar a transcrição Whisper."}];
        }
        return nil;
    }

    NSMutableString *transcript = [NSMutableString string];
    const int segmentCount = whisper_full_n_segments(context);

    for (int index = 0; index < segmentCount; index++) {
        const char *text = whisper_full_get_segment_text(context, index);
        if (text != nullptr) {
            [transcript appendString:[NSString stringWithUTF8String:text]];
        }
    }

    whisper_free(context);

    return [transcript stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
