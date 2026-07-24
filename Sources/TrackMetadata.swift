import Foundation

struct TrackMetadata: Equatable, Hashable, Sendable {
    let artist: String
    let title: String

    var displayName: String {
        "\(artist) — \(title)"
    }

    var bandcampSearchURL: URL? {
        var components = URLComponents(string: "https://bandcamp.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(artist) \(title)")]
        return components?.url
    }

    static func parse(_ rawValue: String) -> TrackMetadata {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = value.range(of: " - ") {
            let artist = value[..<separator.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = value[separator.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty, !title.isEmpty {
                return TrackMetadata(artist: artist, title: title)
            }
        }

        return TrackMetadata(artist: "9128", title: value.isEmpty ? "Live radio" : value)
    }
}
