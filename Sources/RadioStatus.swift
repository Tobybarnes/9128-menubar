import Foundation

struct RadioStatus: Decodable, Sendable {
    let status: String
    let currentTrack: RadioTrack
    let history: [RadioHistoryItem]

    var isOnline: Bool { status == "online" }

    enum CodingKeys: String, CodingKey {
        case status
        case currentTrack = "current_track"
        case history
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct RadioTrack: Decodable, Equatable, Sendable {
    let title: String
    let startedAt: Date?
    let artworkURL: URL?
    let largeArtworkURL: URL?

    var metadata: TrackMetadata { TrackMetadata.parse(title) }
    var preferredArtworkURL: URL? { largeArtworkURL ?? artworkURL }

    enum CodingKeys: String, CodingKey {
        case title
        case startedAt = "start_time"
        case artworkURL = "artwork_url"
        case largeArtworkURL = "artwork_url_large"
    }
}

struct RadioHistoryItem: Decodable, Equatable, Sendable {
    let title: String
    var metadata: TrackMetadata { TrackMetadata.parse(title) }
}
