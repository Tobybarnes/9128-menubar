import Foundation

@MainActor
final class ScrobbleCoordinator: NSObject {
    private let radio: RadioService
    private let player: PlayerController
    private let lastFM: LastFMManager
    private var timer: Timer?
    private var activeTrack: RadioTrack?
    private var listened: TimeInterval = 0
    private var listeningStartedAt: Date?
    private var lastTickAt: Date?
    private var hasScrobbled = false
    private var wasPlaying = false

    init(radio: RadioService, player: PlayerController, lastFM: LastFMManager) {
        self.radio = radio
        self.player = player
        self.lastFM = lastFM
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func timerFired() {
        tick(at: Date())
    }

    func tick(at now: Date) {
        player.refreshPlaybackState()
        guard let incoming = radio.currentTrack else {
            lastTickAt = now
            wasPlaying = player.isPlaying
            return
        }

        var sentNowPlaying = false
        if activeTrack?.title != incoming.title || activeTrack?.startedAt != incoming.startedAt {
            finishPreviousTrack(nextTrack: incoming)
            activeTrack = incoming
            listened = 0
            listeningStartedAt = player.isPlaying ? now : nil
            lastTickAt = now
            hasScrobbled = false
            if player.isPlaying {
                lastFM.updateNowPlaying(incoming.metadata)
                sentNowPlaying = true
            }
        }

        if player.isPlaying {
            if !wasPlaying && !sentNowPlaying {
                listeningStartedAt = listeningStartedAt ?? now
                lastFM.updateNowPlaying(incoming.metadata)
            }
            if let lastTickAt {
                listened += min(max(now.timeIntervalSince(lastTickAt), 0), 2)
            }
            if !hasScrobbled,
               ScrobblePolicy.shouldScrobble(listened: listened, trackDuration: nil) {
                submit(incoming)
            }
        }

        lastTickAt = now
        wasPlaying = player.isPlaying
    }

    private func finishPreviousTrack(nextTrack: RadioTrack) {
        guard let previous = activeTrack, !hasScrobbled else { return }
        let duration: TimeInterval?
        if let previousStart = previous.startedAt, let nextStart = nextTrack.startedAt {
            duration = nextStart.timeIntervalSince(previousStart)
        } else {
            duration = nil
        }

        if ScrobblePolicy.shouldScrobble(listened: listened, trackDuration: duration) {
            submit(previous)
        }
    }

    private func submit(_ track: RadioTrack) {
        guard lastFM.isConnected else { return }
        lastFM.scrobble(track.metadata, listenedAt: listeningStartedAt ?? Date())
        hasScrobbled = true
    }
}
