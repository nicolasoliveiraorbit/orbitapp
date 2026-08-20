import Foundation

// MARK: - Theme Diagnostics

enum OrbitThemeDiagnostics {
    private static let eventsKey = "orbit.themeDiagnostics.events"
    private static let maxStoredEvents = 120

    static func record(stage: String, previousTheme: String? = nil, requestedTheme: String? = nil, appliedTheme: String? = nil, message: String = "") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var event: [String: String] = [
            "timestamp": timestamp,
            "stage": stage,
            "storedTheme": UserDefaults.standard.string(forKey: OrbitColorTheme.storageKey) ?? "",
            "currentTheme": MatrixTheme.current.rawValue,
            "colorScheme": MatrixTheme.current.usesLightGlass ? "light" : "dark",
            "usesLightGlass": MatrixTheme.current.usesLightGlass ? "true" : "false",
            "message": message
        ]

        if let previousTheme { event["previousTheme"] = previousTheme }
        if let requestedTheme { event["requestedTheme"] = requestedTheme }
        if let appliedTheme { event["appliedTheme"] = appliedTheme }
        if let mainWindow = JarvisWindowManager.shared.currentMainWindowDiagnostics() {
            event.merge(mainWindow) { _, new in new }
        }

        var events = snapshot()
        events.append(event)
        if events.count > maxStoredEvents {
            events = Array(events.suffix(maxStoredEvents))
        }
        UserDefaults.standard.set(events, forKey: eventsKey)
        OrbitLogger.shared.log("[Theme] \(stage): previous=\(previousTheme ?? "") requested=\(requestedTheme ?? "") applied=\(appliedTheme ?? "") \(message)")
    }

    static func snapshot() -> [[String: String]] {
        UserDefaults.standard.array(forKey: eventsKey) as? [[String: String]] ?? []
    }

    static func currentSnapshot() -> [String: Any] {
        [
            "storedTheme": UserDefaults.standard.string(forKey: OrbitColorTheme.storageKey) ?? "",
            "currentTheme": MatrixTheme.current.rawValue,
            "displayName": MatrixTheme.current.displayName,
            "usesLightGlass": MatrixTheme.current.usesLightGlass,
            "colorScheme": MatrixTheme.current.usesLightGlass ? "light" : "dark",
            "events": snapshot()
        ]
    }
}
