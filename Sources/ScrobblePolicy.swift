import Foundation

enum ScrobblePolicy {
    static func requiredListenTime(trackDuration: TimeInterval?) -> TimeInterval? {
        guard let trackDuration else { return 240 }
        guard trackDuration >= 30 else { return nil }
        return min(trackDuration / 2, 240)
    }

    static func shouldScrobble(listened: TimeInterval, trackDuration: TimeInterval?) -> Bool {
        guard let threshold = requiredListenTime(trackDuration: trackDuration) else { return false }
        return listened >= threshold
    }
}
