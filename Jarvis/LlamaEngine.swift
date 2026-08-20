//
//  LlamaEngine.swift
//  Orbit
//
//  Created by Ehron on 12/07/26.
//

import Foundation

extension LlamaBridge: @unchecked Sendable {}

private final class LlamaGenerationCancellation: @unchecked Sendable {
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var cancelled = false

    nonisolated init() {}

    nonisolated var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    nonisolated func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

final class LlamaEngine: @unchecked Sendable {

    struct GenerationMetrics: Sendable {
        let outputTokenEstimate: Int
        let duration: TimeInterval

        var tokensPerSecond: Double {
            guard duration > 0 else { return 0 }
            return Double(outputTokenEstimate) / duration
        }
    }

    struct BackendStatus: Sendable {
        let mode: String
        let deviceSummary: String
        let gpuLayerCount: Int
    }

    nonisolated static let shared = LlamaEngine()

    nonisolated(unsafe) private var bridge: LlamaBridge?
    nonisolated(unsafe) private var currentModelPath: String?
    nonisolated(unsafe) private var currentLastGenerationMetrics: GenerationMetrics?
    nonisolated private let lock = NSLock()
    nonisolated private let generationQueue = DispatchQueue(label: "com.ehron.orbit.llama-generation", qos: .userInitiated)

    nonisolated private init() {}

    nonisolated var isModelLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return bridge?.isModelLoaded ?? false
    }

    nonisolated var loadedModelPath: String? {
        lock.lock()
        defer { lock.unlock() }
        return currentModelPath
    }

    nonisolated var lastGenerationMetrics: GenerationMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return currentLastGenerationMetrics
    }

    nonisolated var backendStatus: BackendStatus {
        lock.lock()
        defer { lock.unlock() }

        guard let activeBridge = bridge, activeBridge.isModelLoaded else {
            return BackendStatus(mode: "unloaded", deviceSummary: "modelo não carregado", gpuLayerCount: 0)
        }

        let mode = activeBridge.backendMode.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceSummary = activeBridge.backendDeviceSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return BackendStatus(
            mode: mode.isEmpty ? "unknown" : mode,
            deviceSummary: deviceSummary.isEmpty ? "não informado" : deviceSummary,
            gpuLayerCount: activeBridge.gpuLayerCount
        )
    }

    nonisolated func loadModel(at path: String) throws {
        lock.lock()
        defer { lock.unlock() }

        OrbitLogger.shared.log("[LlamaEngine] loadModel: \(path)")

        if let existing = bridge, existing.isModelLoaded, currentModelPath == path {
            OrbitLogger.shared.log("[LlamaEngine] Modelo já carregado, ignorando")
            return
        }

        bridge?.unload()
        bridge = nil
        currentModelPath = nil

        do {
            let newBridge = try LlamaBridge.loadModel(atPath: path)
            bridge = newBridge
            currentModelPath = path
            OrbitLogger.shared.log("[LlamaEngine] Modelo carregado com sucesso")
        } catch {
            OrbitLogger.shared.error("[LlamaEngine] Falha ao carregar modelo: \(error.localizedDescription)")
            throw error
        }
    }

    nonisolated func generate(
        prompt: String,
        maxTokens: Int = 700,
        temperature: Double = 0.2,
        topP: Double = 0.9,
        topK: Int = 80,
        repetitionPenalty: Double = 1.05,
        timeout: TimeInterval = 240
    ) async throws -> String {
        let activeBridge = try loadedBridge()

        OrbitLogger.shared.log("[LlamaEngine] Gerando resposta (prompt=\(prompt.count) chars, maxTokens=\(maxTokens))")

        let cancellation = LlamaGenerationCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                generationQueue.async {
                    guard cancellation.isCancelled == false else {
                        OrbitLogger.shared.log("[LlamaEngine] Geração cancelada antes de iniciar")
                        DispatchQueue.main.async {
                            continuation.resume(throwing: CancellationError())
                        }
                        return
                    }

                    do {
                        let startedAt = Date()
                        let result = try activeBridge.generate(
                            withPrompt: prompt,
                            maxTokens: maxTokens,
                            temperature: temperature,
                            topP: topP,
                            topK: topK,
                            repetitionPenalty: repetitionPenalty,
                            timeout: timeout
                        )
                        let duration = Date().timeIntervalSince(startedAt)
                        self.storeGenerationMetrics(for: result, duration: duration)

                        DispatchQueue.main.async {
                            if cancellation.isCancelled {
                                OrbitLogger.shared.log("[LlamaEngine] Resultado descartado porque a geração foi cancelada")
                                continuation.resume(throwing: CancellationError())
                            } else if result.isEmpty {
                                OrbitLogger.shared.warn("[LlamaEngine] Resultado vazio do LLM")
                                continuation.resume(throwing: NSError(
                                    domain: "LlamaEngine",
                                    code: -3,
                                    userInfo: [NSLocalizedDescriptionKey: "O LLM retornou uma resposta vazia."]
                                ))
                            } else {
                                OrbitLogger.shared.log("[LlamaEngine] Resposta gerada: \(result.count) chars")
                                continuation.resume(returning: result)
                            }
                        }
                    } catch {
                        OrbitLogger.shared.error("[LlamaEngine] Erro na geração: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            if cancellation.isCancelled {
                                continuation.resume(throwing: CancellationError())
                            } else {
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    nonisolated private func loadedBridge() throws -> LlamaBridge {
        lock.lock()
        defer { lock.unlock() }

        guard let activeBridge = bridge, activeBridge.isModelLoaded else {
            OrbitLogger.shared.error("[LlamaEngine] Modelo não está carregado")
            throw NSError(
                domain: "LlamaEngine",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Modelo LLM não está carregado."]
            )
        }

        return activeBridge
    }

    nonisolated private func storeGenerationMetrics(for result: String, duration: TimeInterval) {
        let tokenEstimate = max(1, Int(ceil(Double(result.count) / 4.0)))
        lock.lock()
        currentLastGenerationMetrics = GenerationMetrics(outputTokenEstimate: tokenEstimate, duration: duration)
        lock.unlock()
    }

    nonisolated func unload() {
        lock.lock()
        defer { lock.unlock() }
        OrbitLogger.shared.log("[LlamaEngine] Descarregando modelo")
        bridge?.unload()
        bridge = nil
        currentModelPath = nil
        currentLastGenerationMetrics = nil
    }
}
