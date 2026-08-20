//
//  OrbitInternetSettings.swift
//  Orbit
//
//  Created by EVA on 03/08/26.
//

import Foundation
import Combine

enum OrbitInternetPreferences {
    private static let assistantSearchKey = "orbit.internet.assistantSearchEnabled"
    private static let suggestionSearchKey = "orbit.internet.suggestionSearchEnabled"

    static var isAssistantSearchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: assistantSearchKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: assistantSearchKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: assistantSearchKey) }
    }

    static var isSuggestionSearchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: suggestionSearchKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: suggestionSearchKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: suggestionSearchKey) }
    }
}

@MainActor
final class OrbitInternetSettings: ObservableObject {
    static let shared = OrbitInternetSettings()

    @Published var isAssistantSearchEnabled: Bool {
        didSet { OrbitInternetPreferences.isAssistantSearchEnabled = isAssistantSearchEnabled }
    }

    @Published var isSuggestionSearchEnabled: Bool {
        didSet { OrbitInternetPreferences.isSuggestionSearchEnabled = isSuggestionSearchEnabled }
    }

    @Published private(set) var statusMessage = "Conexão pronta para pesquisas sob demanda."
    @Published private(set) var lastCheckedText = "Ainda não testado nesta sessão."
    @Published private(set) var connectionSpeedText = "Velocidade ainda não medida."
    @Published private(set) var isCheckingConnection = false

    private init() {
        isAssistantSearchEnabled = OrbitInternetPreferences.isAssistantSearchEnabled
        isSuggestionSearchEnabled = OrbitInternetPreferences.isSuggestionSearchEnabled
    }

    func resetConnection() {
        statusMessage = "Resetando sessão de rede..."
        URLSession.shared.reset {
            Task { @MainActor in
                OrbitInternetSettings.shared.statusMessage = "Sessão de rede resetada. A próxima busca abre uma conexão nova."
                OrbitInternetSettings.shared.lastCheckedText = "Reset executado agora."
                OrbitInternetSettings.shared.connectionSpeedText = "Velocidade ainda não medida."
            }
        }
    }

    func testConnection() async {
        _ = await testConnectionSummary()
    }

    func testConnectionSummary() async -> String {
        guard isCheckingConnection == false else {
            return "Já estou checando a conexão com a internet."
        }
        isCheckingConnection = true
        statusMessage = "Testando busca na internet..."

        let summary: String
        do {
            let speedText = await measureConnectionSpeed()
            let results = try await OrbitWebSearchService.search(query: "OpenAI", limit: 1)
            if let firstResult = results.first {
                statusMessage = "Internet ativa. Busca rápida retornou resultado."
                lastCheckedText = firstResult.title
                connectionSpeedText = speedText
                summary = "Conexão com a internet ativa. A busca rápida retornou: \(firstResult.title)."
            } else {
                statusMessage = "Conexão respondeu, mas a busca não retornou resultados."
                lastCheckedText = "Sem resultado no teste."
                connectionSpeedText = speedText
                summary = "A conexão respondeu, mas a busca rápida não retornou resultados agora."
            }
        } catch {
            statusMessage = "Falha ao consultar internet: \(error.localizedDescription)"
            lastCheckedText = "Erro no teste."
            connectionSpeedText = "Falha ao medir velocidade."
            summary = "Falha ao consultar internet: \(error.localizedDescription)"
        }

        isCheckingConnection = false
        return summary
    }

    private func measureConnectionSpeed() async -> String {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=1000000") else {
            return "Medidor indisponível."
        }

        let startedAt = Date()
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                return "Medição indisponível (HTTP \(httpResponse.statusCode))."
            }

            let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
            let megabitsPerSecond = (Double(data.count) * 8.0) / elapsed / 1_000_000.0
            let latencyMilliseconds = Int(elapsed * 1000)
            return String(format: "%.1f Mbps em %d ms", megabitsPerSecond, latencyMilliseconds)
        } catch {
            return "Medição indisponível: \(error.localizedDescription)"
        }
    }
}
