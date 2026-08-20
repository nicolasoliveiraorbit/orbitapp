import AppKit
import Combine
import Foundation

@MainActor
final class OrbitUpdaterController: ObservableObject {
    static let shared = OrbitUpdaterController()

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/nicolasoliveiraorbit/orbitapp/releases/latest")!
    private let requestTimeout: TimeInterval = 20

    private init() {}

    func checkForUpdates() {
        Task {
            await checkForUpdatesFromGitHub()
        }
    }

    private func checkForUpdatesFromGitHub() async {
        do {
            guard let release = try await fetchLatestRelease() else {
                showAlert(
                    title: "Orbit está atualizado",
                    message: "Nenhuma atualização estável foi publicada ainda."
                )
                return
            }

            let update = try availableUpdate(from: release)

            guard let update else {
                showAlert(
                    title: "Orbit está atualizado",
                    message: "Você já está usando a versão mais recente do Orbit."
                )
                return
            }

            let shouldDownload = showUpdateAvailableAlert(update)
            guard shouldDownload else { return }

            let downloadedURL = try await downloadUpdate(update)
            showDownloadCompletedAlert(downloadedURL)
        } catch {
            showAlert(
                title: "Não foi possível verificar atualizações",
                message: updateErrorMessage(for: error)
            )
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease? {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: requestTimeout)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Orbit-Updater", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return nil
        }
        try validateHTTPResponse(response)

        do {
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw OrbitUpdateError.invalidResponse
        }
    }

    private func availableUpdate(from release: GitHubRelease) throws -> OrbitAvailableUpdate? {
        guard release.draft == false, release.prerelease == false else {
            return nil
        }

        let remoteVersion = try SemanticVersion(tagName: release.tagName)
        let installedVersion = try currentAppVersion()

        guard remoteVersion > installedVersion else {
            return nil
        }

        let expectedAssetName = "Orbit-v\(remoteVersion.normalizedString).zip"
        let zipAsset = release.assets.first { asset in
            asset.name == expectedAssetName
        } ?? release.assets.first { asset in
            let lowercasedName = asset.name.lowercased()
            return lowercasedName.hasSuffix(".zip")
                && lowercasedName.contains("orbit")
                && lowercasedName.contains(remoteVersion.normalizedString.lowercased())
        }

        guard let zipAsset else {
            throw OrbitUpdateError.zipAssetNotFound(expectedAssetName)
        }

        guard let downloadURL = zipAsset.browserDownloadURL else {
            throw OrbitUpdateError.invalidDownloadURL
        }

        return OrbitAvailableUpdate(
            version: remoteVersion,
            installedVersion: installedVersion,
            assetName: zipAsset.name,
            downloadURL: downloadURL
        )
    }

    private func currentAppVersion() throws -> SemanticVersion {
        guard let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            throw OrbitUpdateError.missingInstalledVersion
        }

        return try SemanticVersion(versionString)
    }

    private func downloadUpdate(_ update: OrbitAvailableUpdate) async throws -> URL {
        var request = URLRequest(url: update.downloadURL, timeoutInterval: requestTimeout)
        request.setValue("Orbit-Updater", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        try validateHTTPResponse(response)

        let downloadsDirectory = try FileManager.default.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destinationURL = downloadsDirectory.appendingPathComponent(update.assetName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrbitUpdateError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OrbitUpdateError.httpStatus(httpResponse.statusCode)
        }
    }

    private func showUpdateAvailableAlert(_ update: OrbitAvailableUpdate) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Atualização disponível"
        alert.informativeText = "Orbit \(update.version.normalizedString) está disponível. Você está usando a versão \(update.installedVersion.normalizedString)."
        alert.addButton(withTitle: "Baixar Atualização")
        alert.addButton(withTitle: "Agora não")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showDownloadCompletedAlert(_ downloadedURL: URL) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Atualização baixada"
        alert.informativeText = "O arquivo foi salvo em Downloads. Abra o ZIP para instalar a nova versão do Orbit."
        alert.addButton(withTitle: "Mostrar no Finder")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([downloadedURL])
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func updateErrorMessage(for error: Error) -> String {
        if let updateError = error as? OrbitUpdateError {
            return updateError.localizedDescription
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "Sem conexão com a internet. Verifique sua rede e tente novamente."
            case NSURLErrorTimedOut:
                return "A consulta ao GitHub demorou demais. Tente novamente em alguns instantes."
            default:
                return "Falha de rede: \(nsError.localizedDescription)"
            }
        }

        return error.localizedDescription
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft
        case prerelease
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private struct OrbitAvailableUpdate {
    let version: SemanticVersion
    let installedVersion: SemanticVersion
    let assetName: String
    let downloadURL: URL
}

private enum OrbitUpdateError: LocalizedError {
    case missingInstalledVersion
    case invalidVersion(String)
    case invalidResponse
    case httpStatus(Int)
    case zipAssetNotFound(String)
    case invalidDownloadURL

    var errorDescription: String? {
        switch self {
        case .missingInstalledVersion:
            return "Não foi possível ler a versão instalada do Orbit."
        case .invalidVersion(let version):
            return "A versão recebida é inválida: \(version)."
        case .invalidResponse:
            return "O GitHub retornou uma resposta inválida."
        case .httpStatus(let statusCode):
            return "O GitHub retornou HTTP \(statusCode)."
        case .zipAssetNotFound(let expectedName):
            return "A Release mais recente não contém o ZIP esperado: \(expectedName)."
        case .invalidDownloadURL:
            return "A Release mais recente não contém uma URL de download válida para o ZIP."
        }
    }
}

private struct SemanticVersion: Comparable, CustomStringConvertible {
    let components: [Int]
    let normalizedString: String

    init(tagName: String) throws {
        let versionString = tagName.hasPrefix("v") || tagName.hasPrefix("V")
            ? String(tagName.dropFirst())
            : tagName
        try self.init(versionString)
    }

    init(_ versionString: String) throws {
        let trimmedVersion = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        let coreVersion = trimmedVersion.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? trimmedVersion
        let parts = coreVersion.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count >= 2, parts.count <= 3 else {
            throw OrbitUpdateError.invalidVersion(versionString)
        }

        var parsedComponents: [Int] = []
        for part in parts {
            guard let value = Int(part), value >= 0 else {
                throw OrbitUpdateError.invalidVersion(versionString)
            }
            parsedComponents.append(value)
        }

        while parsedComponents.count < 3 {
            parsedComponents.append(0)
        }

        components = parsedComponents
        normalizedString = parsedComponents.map(String.init).joined(separator: ".")
    }

    var description: String {
        normalizedString
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let leftValue = index < lhs.components.count ? lhs.components[index] : 0
            let rightValue = index < rhs.components.count ? rhs.components[index] : 0

            if leftValue != rightValue {
                return leftValue < rightValue
            }
        }

        return false
    }
}
