import AVFoundation
import Foundation

@MainActor
final class PlayerController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var errorMessage: String?
    @Published var volume: Double {
        didSet {
            let clamped = min(max(volume, 0), 1)
            player.volume = Float(clamped)
            UserDefaults.standard.set(clamped, forKey: Self.volumeKey)
        }
    }

    private static let volumeKey = "radio-volume"
    private let player = AVPlayer()

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.volumeKey) as? Double
        volume = stored ?? 0.8
        player.volume = Float(volume)
        player.automaticallyWaitsToMinimizeStalling = true
    }

    func toggle() {
        isPlaying ? stop() : play()
    }

    func play() {
        var components = URLComponents(url: RadioService.streamURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))]
        guard let url = components.url else {
            errorMessage = "The 9128 stream URL is invalid."
            return
        }

        errorMessage = nil
        isPlaying = true
        isBuffering = true
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if isPlaying {
                isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        isBuffering = false
    }

    func refreshPlaybackState() {
        guard isPlaying else { return }
        isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        if player.currentItem?.status == .failed {
            errorMessage = "The stream stopped unexpectedly."
            stop()
        }
    }
}
