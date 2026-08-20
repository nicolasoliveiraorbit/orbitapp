//
//  OrbitTextAssistantChatStore.swift
//  Orbit
//
//  Created by EVA on 03/08/26.
//

import Foundation
import Combine

struct OrbitTextAssistantChatSession: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var turns: [VoiceConversationTurn]
    var isSuperEVAUnlocked: Bool

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        turns: [VoiceConversationTurn] = [],
        isSuperEVAUnlocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.turns = turns
        self.isSuperEVAUnlocked = isSuperEVAUnlocked
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
        case turns
        case isSuperEVAUnlocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        turns = try container.decodeIfPresent([VoiceConversationTurn].self, forKey: .turns) ?? []
        isSuperEVAUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isSuperEVAUnlocked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(turns, forKey: .turns)
        try container.encode(isSuperEVAUnlocked, forKey: .isSuperEVAUnlocked)
    }
}

@MainActor
final class OrbitTextAssistantChatStore: ObservableObject {
    @Published private(set) var sessions: [OrbitTextAssistantChatSession]
    @Published var selectedSessionID: UUID? {
        didSet { saveSelectedSessionID() }
    }

    private let username: String
    private let maxSessions = 24
    private let maxTurnsPerSession = 80

    init(username: String) {
        self.username = username
        let loadedSessions = Self.loadSessions(for: username)
        self.sessions = loadedSessions.isEmpty ? [Self.makeEmptySession()] : loadedSessions
        self.selectedSessionID = Self.loadSelectedSessionID(for: username)

        if selectedSessionID == nil || sessions.contains(where: { $0.id == selectedSessionID }) == false {
            selectedSessionID = sessions.first?.id
        }
    }

    var selectedSession: OrbitTextAssistantChatSession? {
        guard let selectedSessionID else { return sessions.first }
        return sessions.first { $0.id == selectedSessionID } ?? sessions.first
    }

    var selectedTurns: [VoiceConversationTurn] {
        selectedSession?.turns ?? []
    }

    var selectedTitle: String {
        selectedSession?.title ?? "Novo chat"
    }

    var selectedSessionIsSuperEVAUnlocked: Bool {
        selectedSession?.isSuperEVAUnlocked == true
    }

    func createSession() {
        let session = Self.makeEmptySession()
        sessions.insert(session, at: 0)
        trimSessionsIfNeeded()
        selectedSessionID = session.id
        save()
    }

    func deleteSelectedSession() {
        guard let selectedSessionID else { return }
        sessions.removeAll { $0.id == selectedSessionID }

        if sessions.isEmpty {
            sessions = [Self.makeEmptySession()]
        }

        self.selectedSessionID = sessions.first?.id
        save()
    }

    func unlockSuperEVAForSelectedSession() {
        ensureSelectedSession()
        guard let selectedSessionID,
              let index = sessions.firstIndex(where: { $0.id == selectedSessionID }) else { return }

        sessions[index].isSuperEVAUnlocked = true
        sessions[index].updatedAt = Date()
        save()
    }

    @discardableResult
    func appendTurn(userText: String, assistantText: String, usedInternet: Bool = false) -> VoiceConversationTurn.ID? {
        let cleanUserText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAssistantText = assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanUserText.isEmpty == false, cleanAssistantText.isEmpty == false else { return nil }

        ensureSelectedSession()
        guard let selectedSessionID,
              let index = sessions.firstIndex(where: { $0.id == selectedSessionID }) else { return nil }

        let turn = VoiceConversationTurn(userText: cleanUserText, assistantText: cleanAssistantText, date: Date(), usedInternet: usedInternet)
        sessions[index].turns.append(turn)
        sessions[index].turns = Array(sessions[index].turns.suffix(maxTurnsPerSession))
        sessions[index].updatedAt = Date()

        if sessions[index].title == Self.emptySessionTitle {
            sessions[index].title = Self.fallbackTitle(userText: cleanUserText, assistantText: cleanAssistantText)
        }

        let updatedSession = sessions.remove(at: index)
        sessions.insert(updatedSession, at: 0)
        self.selectedSessionID = updatedSession.id
        trimSessionsIfNeeded()
        save()
        return turn.id
    }

    private func ensureSelectedSession() {
        if sessions.isEmpty {
            let session = Self.makeEmptySession()
            sessions = [session]
            selectedSessionID = session.id
        } else if selectedSessionID == nil || sessions.contains(where: { $0.id == selectedSessionID }) == false {
            selectedSessionID = sessions.first?.id
        }
    }

    private func trimSessionsIfNeeded() {
        if sessions.count > maxSessions {
            sessions = Array(sessions.prefix(maxSessions))
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: Self.sessionsKey(for: username))
        saveSelectedSessionID()
    }

    private func saveSelectedSessionID() {
        if let selectedSessionID {
            UserDefaults.standard.set(selectedSessionID.uuidString, forKey: Self.selectedSessionKey(for: username))
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedSessionKey(for: username))
        }
    }

    func updateTitle(for sessionID: UUID, title: String) {
        let cleanTitle = Self.normalizedTitle(title)
        guard cleanTitle.isEmpty == false,
              let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        sessions[index].title = cleanTitle
        save()
    }

    private static let emptySessionTitle = "Novo chat"

    private static func makeEmptySession() -> OrbitTextAssistantChatSession {
        OrbitTextAssistantChatSession(title: emptySessionTitle)
    }

    private static func fallbackTitle(userText: String, assistantText: String) -> String {
        let normalized = normalizedTitleInput(userText)
        let lowercased = normalized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()

        if lowercased.contains("traduz") || lowercased.contains("translate") {
            return "Tradução para inglês"
        }
        if lowercased.contains("clima") || lowercased.contains("previsao") || lowercased.contains("tempo hoje") {
            return "Previsão do tempo"
        }
        if lowercased.contains("perfil") || lowercased.contains("sobre mim") {
            return "Perfil pessoal"
        }
        if lowercased.contains("demanda") || lowercased.contains("tarefa") || lowercased.contains("pendente") {
            return "Demandas do Orbit"
        }
        if lowercased.contains("status") || lowercased.contains("funcionando") {
            return "Status do Orbit"
        }

        let stopWords: Set<String> = [
            "a", "agora", "ai", "as", "com", "como", "da", "das", "de", "diga", "do", "dos", "e", "ela", "ele", "em", "eu", "isso", "me", "meu", "minha", "no", "nos", "o", "os", "para", "por", "que", "quero", "sobre", "um", "uma", "voce", "você"
        ]
        let words = lowercased
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && stopWords.contains($0) == false }
            .prefix(5)

        let title = words
            .map { word in word.prefix(1).uppercased() + String(word.dropFirst()) }
            .joined(separator: " ")
        return title.isEmpty ? normalizedTitle(assistantText) : normalizedTitle(title)
    }

    private static func normalizedTitleInput(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedTitle(_ text: String) -> String {
        let compact = normalizedTitleInput(text)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'`.,;:!?-")))
        return compact.isEmpty ? emptySessionTitle : String(compact.prefix(54))
    }

    private static func loadSessions(for username: String) -> [OrbitTextAssistantChatSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey(for: username)),
              let sessions = try? JSONDecoder().decode([OrbitTextAssistantChatSession].self, from: data) else {
            return []
        }
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    private static func loadSelectedSessionID(for username: String) -> UUID? {
        guard let rawValue = UserDefaults.standard.string(forKey: selectedSessionKey(for: username)) else { return nil }
        return UUID(uuidString: rawValue)
    }

    private static func sessionsKey(for username: String) -> String {
        "orbit.textAssistant.sessions.\(username)"
    }

    private static func selectedSessionKey(for username: String) -> String {
        "orbit.textAssistant.selectedSession.\(username)"
    }
}
