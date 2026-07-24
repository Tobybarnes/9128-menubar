import Foundation

@MainActor
final class AppModel: ObservableObject {
    let radio = RadioService()
    let player = PlayerController()
    let lastFM = LastFMManager()
    let launchAtLogin = LaunchAtLoginController()
    private let scrobbleCoordinator: ScrobbleCoordinator

    init() {
        scrobbleCoordinator = ScrobbleCoordinator(
            radio: radio,
            player: player,
            lastFM: lastFM
        )
        radio.start()
        scrobbleCoordinator.start()
    }
}
