//
//  LLMModelInstaller.swift
//  Orbit
//
//  Created by Ehron on 12/07/26.
//

import Foundation
import Combine

final class LLMModelInstaller: NSObject, ObservableObject, URLSessionDownloadDelegate {

    static let shared = LLMModelInstaller()

    static let modelFileName = "Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
    static let modelSizeText = "2,5 GB"
    static let modelDownloadURL = URL(string: "https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf")!

    @Published var isInstalling = false
    @Published var downloadProgress: Double = 0
    @Published var installProgress: Double = 0
    @Published var statusText = "Modelo de IA não instalado."

    private var continuation: CheckedContinuation<Void, Error>?
    private var activeModelLoadTask: Task<Void, Error>?
    private let modelLoadTimeoutSeconds: TimeInterval = 180
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()

        if Self.isModelInstalled {
            statusText = "Modelo de IA instalado."
            downloadProgress = 1
            installProgress = 1
        }
    }

    static var modelsFolderURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Orbit/Models/LLM", isDirectory: true)
    }

    static var modelURL: URL {
        modelsFolderURL.appendingPathComponent(modelFileName)
    }

    private static var legacyModelURLs: [URL] {
        [
            modelsFolderURL.appendingPathComponent("Qwen_Qwen3-0.6B-Q6_K.gguf")
        ]
    }

    static var isModelInstalled: Bool {
        let exists = FileManager.default.fileExists(atPath: modelURL.path)
        guard exists else {
            if legacyModelURLs.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                OrbitLogger.shared.warn("[LLMModelInstaller] Modelo antigo encontrado, mas a EVA exige \(modelFileName).")
                OrbitModuleDownloadDiagnostics.record(
                    module: "EVA",
                    stage: "legacy_model_detected",
                    message: "Modelo antigo encontrado. Sera baixado o modelo atual: \(modelFileName)"
                )
            }
            return false
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: modelURL.path),
           let size = attrs[.size] as? Int64 {
            let minSize: Int64 = 2_000 * 1024 * 1024
            if size < minSize {
                OrbitLogger.shared.warn("[LLMModelInstaller] Arquivo do modelo muito pequeno (\(size) bytes), deletando...")
                try? FileManager.default.removeItem(at: modelURL)
                return false
            }
        }
        return true
    }

    static var installedModelByteCount: Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: modelURL.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }

    func ensureModelLoaded() async throws {
        OrbitLogger.shared.log("[LLMModelInstaller] ensureModelLoaded: verificando modelo...")
        let installed = LLMModelInstaller.isModelInstalled
        OrbitLogger.shared.log("[LLMModelInstaller] Modelo instalado: \(installed)")

        if installed {
            await MainActor.run {
                statusText = "Modelo de IA instalado."
                downloadProgress = 1
                installProgress = 1
            }
            try await loadModelInBackground(path: LLMModelInstaller.modelURL.path)
            return
        }

        try await installModel()

        try await loadModelInBackground(path: LLMModelInstaller.modelURL.path)
    }

    private func loadModelInBackground(path: String) async throws {
        let loadTask: Task<Void, Error>

        if let activeModelLoadTask {
            loadTask = activeModelLoadTask
            OrbitLogger.shared.log("[LLMModelInstaller] Aguardando carregamento de modelo já em andamento")
            OrbitModuleDownloadDiagnostics.record(
                module: "EVA",
                stage: "load_join_existing",
                message: "Aguardando carregamento já iniciado."
            )
        } else {
            OrbitLogger.shared.log("[LLMModelInstaller] Carregando modelo em background: \(path)")
            OrbitModuleDownloadDiagnostics.record(
                module: "EVA",
                stage: "load_start",
                message: "Carregando modelo em memoria: \(path)"
            )

            loadTask = Task.detached(priority: .userInitiated) {
                try LlamaEngine.shared.loadModel(at: path)
            }
            activeModelLoadTask = loadTask
        }

        do {
            try await waitForModelLoad(loadTask)
            activeModelLoadTask = nil
            OrbitLogger.shared.log("[LLMModelInstaller] Modelo carregado com sucesso")
            OrbitModuleDownloadDiagnostics.record(
                module: "EVA",
                stage: "load_success",
                message: "Modelo carregado com sucesso."
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain != "LLMModelInstaller" || nsError.code != -20 {
                activeModelLoadTask = nil
            }

            OrbitLogger.shared.error("[LLMModelInstaller] Falha ao carregar modelo: \(error.localizedDescription)")
            OrbitModuleDownloadDiagnostics.record(
                module: "EVA",
                stage: "load_failed",
                message: error.localizedDescription,
                isError: true
            )
            throw error
        }
    }

    private func waitForModelLoad(_ loadTask: Task<Void, Error>) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await loadTask.value
            }
            group.addTask { [modelLoadTimeoutSeconds] in
                try await Task.sleep(nanoseconds: UInt64(modelLoadTimeoutSeconds * 1_000_000_000))
                throw NSError(
                    domain: "LLMModelInstaller",
                    code: -20,
                    userInfo: [NSLocalizedDescriptionKey: "A EVA ainda está carregando o modelo. Aguarde mais um pouco antes de tentar novamente."]
                )
            }

            defer { group.cancelAll() }
            try await group.next()
        }
    }

    func installModel() async throws {
        if LLMModelInstaller.isModelInstalled {
            await MainActor.run {
                statusText = "Modelo de IA já instalado."
                downloadProgress = 1
                installProgress = 1
            }
            return
        }

        guard isInstalling == false else { return }

        OrbitLogger.shared.log("[LLMModelInstaller] Iniciando download do modelo de \(Self.modelDownloadURL)")
        OrbitModuleDownloadDiagnostics.record(
            module: "EVA",
            stage: "download_start",
            message: "Baixando \(Self.modelFileName) de \(Self.modelDownloadURL.absoluteString)"
        )

        try FileManager.default.createDirectory(
            at: Self.modelsFolderURL,
            withIntermediateDirectories: true
        )

        await MainActor.run {
            isInstalling = true
            downloadProgress = 0
            installProgress = 0
            statusText = "Baixando EVA... (2,5 GB)"
        }

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.downloadTask(with: Self.modelDownloadURL)
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        DispatchQueue.main.async {
            self.downloadProgress = progress
            let mb = Double(totalBytesWritten) / (1024 * 1024)
            let totalMB = Double(totalBytesExpectedToWrite) / (1024 * 1024)
            self.statusText = "Baixando modelo... \(Int(mb))/\(Int(totalMB)) MB (\(Int(progress * 100))%)"
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        OrbitLogger.shared.log("[LLMModelInstaller] Download concluido, instalando...")
        OrbitModuleDownloadDiagnostics.record(
            module: "EVA",
            stage: "download_finished",
            message: "Download concluido em arquivo temporario: \(location.path)"
        )

        do {
            DispatchQueue.main.async {
                self.statusText = "Instalando modelo na pasta do Orbit..."
                self.installProgress = 0.35
            }

            let destinationURL = Self.modelURL
            let temporaryURL = destinationURL.appendingPathExtension("download")

            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try FileManager.default.removeItem(at: temporaryURL)
            }

            try FileManager.default.moveItem(at: location, to: temporaryURL)

            DispatchQueue.main.async {
                self.installProgress = 0.72
            }

            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)

            OrbitLogger.shared.log("[LLMModelInstaller] Modelo instalado com sucesso em: \(destinationURL.path)")
            OrbitModuleDownloadDiagnostics.record(
                module: "EVA",
                stage: "installed",
                message: "Modelo instalado em: \(destinationURL.path)"
            )

            DispatchQueue.main.async {
                self.downloadProgress = 1
                self.installProgress = 1
                self.isInstalling = false
                self.statusText = "Modelo de IA instalado."
            }

            continuation?.resume()
            continuation = nil
        } catch {
            OrbitLogger.shared.error("[LLMModelInstaller] Falha ao instalar modelo: \(error.localizedDescription)")
            OrbitModuleDownloadDiagnostics.record(
                module: "EVA",
                stage: "install_failed",
                message: error.localizedDescription,
                isError: true
            )

            DispatchQueue.main.async {
                self.isInstalling = false
                self.statusText = "Falha ao instalar modelo: \(error.localizedDescription)"
            }
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }

        OrbitLogger.shared.error("[LLMModelInstaller] Download falhou: \(error.localizedDescription)")
        OrbitModuleDownloadDiagnostics.record(
            module: "EVA",
            stage: "download_failed",
            message: error.localizedDescription,
            isError: true
        )

        DispatchQueue.main.async {
            self.isInstalling = false
            self.statusText = "Falha no download: \(error.localizedDescription)"
        }

        continuation?.resume(throwing: error)
        continuation = nil
    }
}
