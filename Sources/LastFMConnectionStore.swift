import Foundation

protocol LastFMKeychainStoring {
    func string(for account: String) throws -> String?
    func set(_ value: String, for account: String) throws
    func delete(_ account: String) throws
}

extension KeychainStore: LastFMKeychainStoring {}

struct LastFMConnection: Codable, Equatable {
    var configuration: LastFMConfiguration
    var session: LastFMSession?
}

struct LastFMConnectionStore {
    static let service = "com.tobybarnes.radio9128.lastfm"
    static let account = "connection"

    private let store: any LastFMKeychainStoring
    private let legacyStore: any LastFMKeychainStoring

    init(
        store: any LastFMKeychainStoring = KeychainStore(service: service),
        legacyStore: any LastFMKeychainStoring = KeychainStore(service: "com.tobybarnes.radio9128.beta4")
    ) {
        self.store = store
        self.legacyStore = legacyStore
    }

    func load(bundledConfiguration: LastFMConfiguration?) throws -> LastFMConnection? {
        if let saved = try store.string(for: Self.account) {
            return try JSONDecoder().decode(LastFMConnection.self, from: Data(saved.utf8))
        }

        guard let bundledConfiguration else { return nil }
        let sessionKey = try legacyStore.string(for: "lastfm-session")
        let username = try legacyStore.string(for: "lastfm-username")
        var session: LastFMSession?
        if let sessionKey, let username,
           !sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session = LastFMSession(username: username, key: sessionKey)
        }

        let connection = LastFMConnection(configuration: bundledConfiguration, session: session)
        try save(connection)
        return connection
    }

    func save(_ connection: LastFMConnection) throws {
        let data = try JSONEncoder().encode(connection)
        try store.set(String(decoding: data, as: UTF8.self), for: Self.account)
    }

    func disconnect(_ connection: LastFMConnection) throws -> LastFMConnection {
        var disconnected = connection
        disconnected.session = nil
        try save(disconnected)
        // The saved record remains authoritative even if old items cannot be removed.
        try? legacyStore.delete("lastfm-session")
        try? legacyStore.delete("lastfm-username")
        return disconnected
    }
}
