
//
//  LlamaBridge.mm
//  Orbit
//
//  Created by Ehron on 12/07/26.
//

#import "LlamaBridge.h"
#import "OrbitLog.h"

#include "llamaCpp/llama.h"
#include <algorithm>
#include <chrono>
#include <vector>
#include <string>

static int32_t OrbitLlamaThreadCount(void) {
    NSInteger activeProcessors = [[NSProcessInfo processInfo] activeProcessorCount];
    NSInteger preferredThreads = activeProcessors > 2 ? activeProcessors - 1 : activeProcessors;
    return (int32_t)std::max<NSInteger>(1, std::min<NSInteger>(preferredThreads, 12));
}

static void OrbitEnsureLlamaBackendInitialized(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        llama_backend_init();
        [OrbitLog log:@"[loadModel] llama.cpp backend inicializado"];
    });
}

static std::vector<ggml_backend_dev_t> OrbitAvailableGPUDevices(void) {
    std::vector<ggml_backend_dev_t> devices;
    const size_t deviceCount = ggml_backend_dev_count();

    for (size_t index = 0; index < deviceCount; index++) {
        ggml_backend_dev_t device = ggml_backend_dev_get(index);
        if (device == nullptr) {
            continue;
        }

        const enum ggml_backend_dev_type type = ggml_backend_dev_type(device);
        if (type == GGML_BACKEND_DEVICE_TYPE_GPU || type == GGML_BACKEND_DEVICE_TYPE_IGPU) {
            devices.push_back(device);
        }
    }

    devices.push_back(nullptr);
    return devices;
}

static NSString *OrbitGPUDeviceSummary(const std::vector<ggml_backend_dev_t> &devices) {
    NSMutableArray<NSString *> *names = [NSMutableArray array];

    for (ggml_backend_dev_t device : devices) {
        if (device == nullptr) {
            continue;
        }

        const char *name = ggml_backend_dev_name(device);
        const char *description = ggml_backend_dev_description(device);
        NSString *deviceName = name != nullptr ? [NSString stringWithUTF8String:name] : @"GPU";
        NSString *deviceDescription = description != nullptr ? [NSString stringWithUTF8String:description] : @"Metal";
        [names addObject:[NSString stringWithFormat:@"%@ (%@)", deviceName, deviceDescription]];
    }

    return names.count > 0 ? [names componentsJoinedByString:@", "] : @"nenhum";
}

static struct llama_model_params OrbitCPUModelParams(void) {
    static ggml_backend_dev_t noDevices[] = { nullptr };
    struct llama_model_params params = llama_model_default_params();
    params.devices = noDevices;
    params.n_gpu_layers = 0;
    params.use_mmap = false;
    params.use_direct_io = false;
    params.use_mlock = false;
    params.use_extra_bufts = false;
    params.no_host = false;
    params.no_alloc = false;
    return params;
}

static bool OrbitExtractTaggedSection(const std::string &text,
                                      const std::string &startTag,
                                      const std::string &endTag,
                                      std::string &section) {
    size_t start = text.find(startTag);
    if (start == std::string::npos) {
        return false;
    }

    start += startTag.size();
    size_t end = text.find(endTag, start);
    if (end == std::string::npos || end < start) {
        return false;
    }

    section = text.substr(start, end - start);

    while (!section.empty() && (section.front() == '\n' || section.front() == '\r')) {
        section.erase(section.begin());
    }
    while (!section.empty() && (section.back() == '\n' || section.back() == '\r')) {
        section.pop_back();
    }

    return true;
}

static std::string OrbitFormattedChatPrompt(struct llama_model *model, NSString *prompt) {
    const char *promptText = [prompt UTF8String];
    if (promptText == nullptr) {
        return "";
    }

    std::string rawPrompt(promptText);
    std::string systemPrompt;
    std::string userPrompt;
    bool hasOrbitMessages =
        OrbitExtractTaggedSection(rawPrompt, "<<ORBIT_SYSTEM>>", "<</ORBIT_SYSTEM>>", systemPrompt) &&
        OrbitExtractTaggedSection(rawPrompt, "<<ORBIT_USER>>", "<</ORBIT_USER>>", userPrompt);

    const char *chatTemplate = llama_model_chat_template(model, nullptr);
    if (chatTemplate == nullptr) {
        if (hasOrbitMessages) {
            return "System:\n" + systemPrompt + "\n\nUser:\n" + userPrompt + "\n\nAssistant:\n";
        }
        return rawPrompt;
    }

    std::vector<llama_chat_message> messages;
    if (hasOrbitMessages) {
        messages.push_back({ "system", systemPrompt.c_str() });
        messages.push_back({ "user", userPrompt.c_str() });
    } else {
        userPrompt = rawPrompt;
        messages.push_back({ "user", userPrompt.c_str() });
    }

    int32_t requiredLength = llama_chat_apply_template(chatTemplate, messages.data(), (int)messages.size(), true, nullptr, 0);
    if (requiredLength <= 0) {
        return userPrompt;
    }

    std::vector<char> buffer(requiredLength + 1, '\0');
    int32_t written = llama_chat_apply_template(chatTemplate, messages.data(), (int)messages.size(), true, buffer.data(), (int32_t)buffer.size());
    if (written <= 0) {
        return userPrompt;
    }

    return std::string(buffer.data(), written);
}

@implementation LlamaBridge {
    struct llama_model *_model;
    const struct llama_vocab *_vocab;
    struct llama_context *_ctx;
    BOOL _loaded;
    NSString *_backendMode;
    NSString *_backendDeviceSummary;
    NSInteger _gpuLayerCount;
}

- (instancetype)initWithModel:(struct llama_model *)model
                       context:(struct llama_context *)context
                   backendMode:(NSString *)backendMode
          backendDeviceSummary:(NSString *)backendDeviceSummary
                 gpuLayerCount:(NSInteger)gpuLayerCount {
    self = [super init];
    if (self) {
        _model = model;
        _vocab = llama_model_get_vocab(model);
        _ctx = context;
        _loaded = YES;
        _backendMode = [backendMode copy];
        _backendDeviceSummary = [backendDeviceSummary copy];
        _gpuLayerCount = gpuLayerCount;
    }
    return self;
}

- (NSString *)backendMode {
    return _backendMode ?: @"";
}

- (NSString *)backendDeviceSummary {
    return _backendDeviceSummary ?: @"";
}

- (NSInteger)gpuLayerCount {
    return _gpuLayerCount;
}

- (void)dealloc {
    [self unload];
}

+ (nullable instancetype)loadModelAtPath:(NSString *)modelPath
                                    error:(NSError * _Nullable * _Nullable)error {
    [OrbitLog log:[NSString stringWithFormat:@"[loadModel] Iniciando carregamento: %@", modelPath]];

    if (modelPath.length == 0) {
        [OrbitLog error:@"[loadModel] Caminho do modelo vazio"];
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Caminho do modelo esta vazio."}];
        }
        return nil;
    }

    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:modelPath];
    NSNumber *fileSize = nil;
    if (fileExists) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:modelPath error:nil];
        fileSize = attrs[NSFileSize];
    }
    [OrbitLog log:[NSString stringWithFormat:@"[loadModel] Arquivo existe: %@, tamanho: %@ bytes",
        fileExists ? @"SIM" : @"NAO", fileSize ?: @"?"]];

    if (!fileExists || fileSize.longLongValue < 100 * 1024 * 1024) {
        [OrbitLog error:[NSString stringWithFormat:@"[loadModel] Arquivo invalido (existe=%d, tamanho=%@)", fileExists, fileSize ?: @"?"]];
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Arquivo do modelo invalido ou muito pequeno. Baixe novamente."}];
        }
        return nil;
    }

    @try {
        OrbitEnsureLlamaBackendInitialized();

        const char *path = [modelPath UTF8String];

        std::vector<ggml_backend_dev_t> gpuDevices = OrbitAvailableGPUDevices();
        const bool supportsGPUOffload = llama_supports_gpu_offload();
        const bool hasGPUDevice = gpuDevices.size() > 1;
        struct llama_model *model = nullptr;
        NSString *backendMode = @"cpu";
        NSString *backendDeviceSummary = @"CPU";
        NSInteger gpuLayerCount = 0;

        if (supportsGPUOffload && hasGPUDevice) {
            NSString *gpuDeviceSummary = OrbitGPUDeviceSummary(gpuDevices);
            struct llama_model_params metalParams = llama_model_default_params();
            metalParams.devices = gpuDevices.data();
            metalParams.n_gpu_layers = -1;
            metalParams.split_mode = LLAMA_SPLIT_MODE_LAYER;
            metalParams.main_gpu = 0;
            metalParams.use_mmap = false;
            metalParams.use_direct_io = false;
            metalParams.use_mlock = false;
            metalParams.use_extra_bufts = true;
            metalParams.no_host = false;
            metalParams.no_alloc = false;

            [OrbitLog log:[NSString stringWithFormat:@"[loadModel] Tentando Metal/GPU: devices=%@, n_gpu_layers=-1, mmap=off",
                gpuDeviceSummary]];
            model = llama_model_load_from_file(path, metalParams);

            if (model == nullptr) {
                [OrbitLog warn:@"[loadModel] Metal/GPU falhou no carregamento; tentando fallback CPU."];
            } else {
                backendMode = @"metal";
                backendDeviceSummary = gpuDeviceSummary;
                gpuLayerCount = -1;
                [OrbitLog log:[NSString stringWithFormat:@"[loadModel] Metal/GPU ativo: devices=%@, n_gpu_layers=todas",
                    backendDeviceSummary]];
            }
        } else {
            [OrbitLog warn:[NSString stringWithFormat:@"[loadModel] Metal/GPU indisponível: supportsGPUOffload=%d, devices=%@",
                supportsGPUOffload, OrbitGPUDeviceSummary(gpuDevices)]];
        }

        if (model == nullptr) {
            struct llama_model_params cpuParams = OrbitCPUModelParams();
            [OrbitLog log:@"[loadModel] Chamando llama_model_load_from_file... modo=cpu-sem-mmap"];
            model = llama_model_load_from_file(path, cpuParams);
        }

        if (model == nullptr) {
            [OrbitLog error:@"[loadModel] llama_model_load_from_file retornou nullptr"];
            if (error) {
                *error = [NSError errorWithDomain:@"LlamaBridge"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"Falha ao carregar o modelo LLM."}];
            }
            return nil;
        }
        [OrbitLog log:@"[loadModel] Modelo carregado com sucesso"];

        struct llama_context_params ctxParams = llama_context_default_params();
        ctxParams.n_ctx = 4096;
        ctxParams.n_batch = 2048;
        ctxParams.n_ubatch = 1024;
        ctxParams.n_threads = OrbitLlamaThreadCount();
        ctxParams.n_threads_batch = OrbitLlamaThreadCount();
        ctxParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_AUTO;

        [OrbitLog log:[NSString stringWithFormat:@"[loadModel] Criando contexto: n_ctx=%u, n_batch=%u, n_ubatch=%u, threads=%d",
            ctxParams.n_ctx, ctxParams.n_batch, ctxParams.n_ubatch, ctxParams.n_threads]];
        struct llama_context *ctx = llama_init_from_model(model, ctxParams);

        if (ctx == nullptr) {
            [OrbitLog error:@"[loadModel] llama_init_from_model retornou nullptr"];
            llama_model_free(model);
            if (error) {
                *error = [NSError errorWithDomain:@"LlamaBridge"
                                             code:-3
                                         userInfo:@{NSLocalizedDescriptionKey: @"Falha ao inicializar o contexto do LLM."}];
            }
            return nil;
        }

        uint32_t actualCtx = llama_n_ctx(ctx);
        uint32_t actualBatch = llama_n_batch(ctx);
        [OrbitLog log:[NSString stringWithFormat:@"[loadModel] Contexto criado: n_ctx_real=%u, n_batch_real=%u",
            actualCtx, actualBatch]];

        return [[LlamaBridge alloc] initWithModel:model
                                         context:ctx
                                     backendMode:backendMode
                            backendDeviceSummary:backendDeviceSummary
                                   gpuLayerCount:gpuLayerCount];
    } @catch (NSException *exception) {
        [OrbitLog error:[NSString stringWithFormat:@"[loadModel] Excecao: %@", exception.reason ?: @"desconhecida"]];
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:-10
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Excecao ao carregar: %@", exception.reason ?: @"desconhecida"]}];
        }
        return nil;
    }
}

- (nullable NSString *)generateWithPrompt:(NSString *)prompt
                                maxTokens:(NSInteger)maxTokens
                                temperature:(double)temperature
                                       topP:(double)topP
                                       topK:(NSInteger)topK
                          repetitionPenalty:(double)repetitionPenalty
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError * _Nullable * _Nullable)error {
    [OrbitLog log:[NSString stringWithFormat:@"[generate] Iniciando geracao (maxTokens=%ld, temp=%.2f, topP=%.2f, topK=%ld, repeat=%.2f)",
        (long)maxTokens, temperature, topP, (long)topK, repetitionPenalty]];

    if (!_loaded || _model == nullptr || _ctx == nullptr || _vocab == nullptr) {
        [OrbitLog error:[NSString stringWithFormat:@"[generate] Modelo nao carregado: loaded=%d, model=%p, ctx=%p, vocab=%p",
            _loaded, _model, _ctx, _vocab]];
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:-4
                                     userInfo:@{NSLocalizedDescriptionKey: @"Modelo LLM nao esta carregado."}];
        }
        return nil;
    }

    @try {
        [OrbitLog log:@"[generate] Limpando KV cache..."];
        llama_memory_clear(llama_get_memory(_ctx), true);

        std::string formattedPrompt = OrbitFormattedChatPrompt(_model, prompt);
        const char *text = formattedPrompt.c_str();
        int32_t textLen = (int32_t)formattedPrompt.size();
        [OrbitLog log:[NSString stringWithFormat:@"[generate] Prompt length: %d bytes", textLen]];

        int32_t nPrompt = llama_tokenize(_vocab, text, textLen, nullptr, 0, false, false);
        [OrbitLog log:[NSString stringWithFormat:@"[generate] Tokenizacao (passo 1): nPrompt=%d", nPrompt]];

        if (nPrompt == INT32_MIN || nPrompt == 0) {
            [OrbitLog error:[NSString stringWithFormat:@"[generate] Tokenizacao falhou: nPrompt=%d", nPrompt]];
            if (error) {
                *error = [NSError errorWithDomain:@"LlamaBridge" code:-5
                                         userInfo:@{NSLocalizedDescriptionKey: @"Tokenizacao falhou."}];
            }
            return nil;
        }
        int32_t nTokens = (nPrompt < 0) ? -nPrompt : nPrompt;

        int32_t nCtx = llama_n_ctx(_ctx);
        int32_t nSeqMax = llama_n_seq_max(_ctx);
        if (nSeqMax == 0) nSeqMax = 1;
        int32_t maxPromptTokens = (nCtx / nSeqMax) - 4;
        [OrbitLog log:[NSString stringWithFormat:@"[generate] nCtx=%d, nSeqMax=%d, maxPromptTokens=%d, nTokens=%d",
            nCtx, nSeqMax, maxPromptTokens, nTokens]];

        if (nTokens > maxPromptTokens) {
            [OrbitLog warn:[NSString stringWithFormat:@"[generate] Prompt truncado de %d para %d tokens", nTokens, maxPromptTokens]];
            nTokens = maxPromptTokens;
        }

        std::vector<llama_token> promptTokens(nTokens);
        int32_t filled = llama_tokenize(_vocab, text, textLen, promptTokens.data(), nTokens, false, false);
        [OrbitLog log:[NSString stringWithFormat:@"[generate] Tokenizacao (passo 2): filled=%d", filled]];

        if (filled < 0) {
            [OrbitLog error:[NSString stringWithFormat:@"[generate] Tokenizacao preenchimento falhou: filled=%d", filled]];
            if (error) {
                *error = [NSError errorWithDomain:@"LlamaBridge" code:-5
                                         userInfo:@{NSLocalizedDescriptionKey: @"Tokenizacao preenchimento falhou."}];
            }
            return nil;
        }

        const int32_t BATCH_SIZE = 1024;
        int32_t offset = 0;
        int32_t chunkCount = 0;
        while (offset < filled) {
            int32_t chunk = filled - offset;
            if (chunk > BATCH_SIZE) chunk = BATCH_SIZE;

            llama_batch batch = llama_batch_init(chunk, 0, 1);
            if (batch.token == nullptr) {
                [OrbitLog error:@"[generate] Falha ao alocar batch"];
                if (error) {
                    *error = [NSError errorWithDomain:@"LlamaBridge" code:-6
                                             userInfo:@{NSLocalizedDescriptionKey: @"Falha ao alocar batch."}];
                }
                return nil;
            }

            for (int32_t i = 0; i < chunk; i++) {
                batch.token   [i] = promptTokens[offset + i];
                batch.pos     [i] = offset + i;
                batch.n_seq_id[i] = 1;
                batch.seq_id [i][0] = 0;
                batch.logits  [i] = (offset + i == filled - 1) ? 1 : 0;
            }
            batch.n_tokens = chunk;

            int32_t decodeResult = llama_decode(_ctx, batch);
            llama_batch_free(batch);
            chunkCount++;

            if (decodeResult < 0) {
                [OrbitLog error:[NSString stringWithFormat:@"[generate] llama_decode falhou no chunk %d (offset=%d, chunk=%d): code=%d",
                    chunkCount, offset, chunk, decodeResult]];
                if (error) {
                    *error = [NSError errorWithDomain:@"LlamaBridge" code:-6
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Falha ao decodificar prompt (code: %d).", decodeResult]}];
                }
                return nil;
            }

            offset += chunk;
        }
        [OrbitLog log:[NSString stringWithFormat:@"[generate] Prompt decodificado: %d chunks, %d tokens", chunkCount, filled]];

        auto sparams = llama_sampler_chain_default_params();
        struct llama_sampler *sampler = llama_sampler_chain_init(sparams);
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k((int32_t)std::max<NSInteger>(1, topK)));
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p((float)topP, 1));
        llama_sampler_chain_add(sampler, llama_sampler_init_temp((float)temperature));
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(128, (float)repetitionPenalty, 0.02f, 0.02f));
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

        for (int32_t i = 0; i < filled; i++) {
            llama_sampler_accept(sampler, promptTokens[i]);
        }

        NSMutableString *result = [NSMutableString string];
        int32_t pos = filled;
        int32_t tokensGenerated = 0;
        auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds((int64_t)(timeout * 1000.0));

        for (NSInteger i = 0; i < maxTokens; i++) {
            if (timeout > 0 && std::chrono::steady_clock::now() >= deadline) {
                [OrbitLog warn:[NSString stringWithFormat:@"[generate] Timeout atingido apos %d tokens", tokensGenerated]];
                break;
            }

            llama_token newToken = llama_sampler_sample(sampler, _ctx, -1);

            if (llama_vocab_is_eog(_vocab, newToken)) {
                [OrbitLog log:[NSString stringWithFormat:@"[generate] EOG atingido no token %d", tokensGenerated]];
                break;
            }

            char buf[256];
            int n = llama_token_to_piece(_vocab, newToken, buf, sizeof(buf) - 1, 0, true);

            if (n > 0) {
                buf[n] = '\0';
                NSString *piece = [NSString stringWithUTF8String:buf];
                if (piece) {
                    [result appendString:piece];
                }
            }

            llama_sampler_accept(sampler, newToken);

            llama_batch nextBatch = llama_batch_init(1, 0, 1);
            nextBatch.token   [0] = newToken;
            nextBatch.pos     [0] = pos;
            nextBatch.n_seq_id[0] = 1;
            nextBatch.seq_id [0][0] = 0;
            nextBatch.logits  [0] = 1;
            nextBatch.n_tokens = 1;
            pos++;

            int32_t decResult = llama_decode(_ctx, nextBatch);
            llama_batch_free(nextBatch);
            tokensGenerated++;

            if (decResult != 0) {
                [OrbitLog error:[NSString stringWithFormat:@"[generate] llama_decode falhou no token %d: code=%d", tokensGenerated, decResult]];
                break;
            }
        }

        llama_sampler_free(sampler);

        NSString *output = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [OrbitLog log:[NSString stringWithFormat:@"[generate] Geracao concluida: %d tokens, resultado=%lu chars",
            tokensGenerated, (unsigned long)output.length]];

        if (output.length == 0 && error) {
            [OrbitLog warn:@"[generate] Resultado vazio"];
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:-7
                                     userInfo:@{NSLocalizedDescriptionKey: @"O LLM retornou uma resposta vazia."}];
        }

        return output.length > 0 ? output : nil;
    } @catch (NSException *exception) {
        [OrbitLog error:[NSString stringWithFormat:@"[generate] Excecao: %@", exception.reason ?: @"desconhecida"]];
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:-13
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Excecao na geracao: %@", exception.reason ?: @"desconhecida"]}];
        }
        return nil;
    }
}

- (void)unload {
    [OrbitLog log:@"[unload] Descarregando modelo..."];
    @try {
        if (_ctx) {
            llama_free(_ctx);
            _ctx = nullptr;
        }

        if (_model) {
            _vocab = nullptr;
            llama_model_free(_model);
            _model = nullptr;
        }

        _loaded = NO;
        [OrbitLog log:@"[unload] Modelo descarregado"];
    } @catch (...) {
        _ctx = nullptr;
        _model = nullptr;
        _vocab = nullptr;
        _loaded = NO;
        [OrbitLog error:@"[unload] Excecao ao descarregar modelo"];
    }
}

- (BOOL)isModelLoaded {
    return _loaded && _model != nullptr && _ctx != nullptr;
}

@end
