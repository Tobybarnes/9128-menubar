import Foundation

struct LastFMConfiguration: Equatable, Sendable {
    let apiKey: String
    let sharedSecret: String

    init?(infoDictionary: [String: Any]) {
        guard let apiKey = Self.value(named: "LastFMAPIKey", in: infoDictionary),
              let sharedSecret = Self.value(named: "LastFMSharedSecret", in: infoDictionary) else {
            return nil
        }

        self.apiKey = apiKey
        self.sharedSecret = sharedSecret
    }

    init?(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    private static func value(named name: String, in dictionary: [String: Any]) -> String? {
        guard let value = dictionary[name] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
