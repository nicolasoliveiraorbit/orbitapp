import Combine
import Foundation
import Sparkle

@MainActor
final class OrbitUpdaterController: ObservableObject {
    static let shared = OrbitUpdaterController()

    private let updaterController: SPUStandardUpdaterController

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
