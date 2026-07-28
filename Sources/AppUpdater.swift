import Combine
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates: Bool

    private let updaterController: SPUStandardUpdaterController?
    private let performCheck: @MainActor () -> Void

    init(startingUpdater: Bool = true) {
        let controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
        canCheckForUpdates = controller.updater.canCheckForUpdates
        performCheck = controller.updater.checkForUpdates

        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    init(canCheckForUpdates: Bool, performCheck: @escaping @MainActor () -> Void) {
        updaterController = nil
        self.canCheckForUpdates = canCheckForUpdates
        self.performCheck = performCheck
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        performCheck()
    }
}
