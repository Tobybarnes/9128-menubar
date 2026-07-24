import AppKit
import Foundation

@MainActor
final class LastFMManager: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case waitingForApproval
        case connected(username: String)
        case failed(String)
    }

    @Published var apiKey: String
    @Published var sharedSecret: String
    @Published private(set) var state: ConnectionState
    @Published private(set) var lastScrobble: String?
    @Published private(set) var activityMessage: String?

    private enum Account {
        static let apiKey = "lastfm-api-key"
        static let sharedSecret = "lastfm-api-secret"
        static let session = "lastfm-session"
        static let username = "lastfm-username"
    }

    private let store = KeychainStore(service: "com.tobybarnes.radio9128")
    private let client = LastFMClient()
    private var pendingToken: String?
    private var sessionKey: String?

    init() {
        apiKey = store.string(for: Account.apiKey) ?? ""
        sharedSecret = store.string(for: Account.sharedSecret) ?? ""
        sessionKey = store.string(for: Account.session)
        if let sessionKey, !sessionKey.isEmpty,
           let username = store.string(for: Account.username), !username.isEmpty {
            state = .connected(username: username)
        } else {
            state = .disconnected
        }
    }

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var credentialsAreConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sharedSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var connectionLabel: String {
        switch state {
        case .disconnected: "Not connected"
        case .connecting: "Connecting…"
        case .waitingForApproval: "Waiting for approval"
        case .connected(let username): "Connected as \(username)"
        case .failed(let message): message
        }
    }

    func saveCredentials() {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = sharedSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty, !cleanSecret.isEmpty else {
            state = .failed("Add both Last.fm credentials.")
            return
        }

        do {
            let credentialsChanged = cleanKey != store.string(for: Account.apiKey) ||
                cleanSecret != store.string(for: Account.sharedSecret)
            try store.set(cleanKey, for: Account.apiKey)
            try store.set(cleanSecret, for: Account.sharedSecret)
            apiKey = cleanKey
            sharedSecret = cleanSecret
            if credentialsChanged {
                store.delete(Account.session)
                store.delete(Account.username)
                sessionKey = nil
                state = .disconnected
            } else if !isConnected {
                state = .disconnected
            }
            activityMessage = "Credentials saved in Keychain."
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func connect() async {
        saveCredentials()
        guard credentialsAreConfigured else { return }
        state = .connecting
        activityMessage = nil

        do {
            let token = try await client.getToken(credentials: credentials)
            pendingToken = token
            var components = URLComponents(string: "https://www.last.fm/api/auth/")!
            components.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "token", value: token)
            ]
            guard let url = components.url else {
                throw LastFMAPIError(code: nil, message: "Could not create the Last.fm approval link.")
            }
            NSWorkspace.shared.open(url)
            state = .waitingForApproval
        } catch {
            handle(error)
        }
    }

    func finishAuthorization() async {
        guard let pendingToken else {
            state = .failed("Start the Last.fm connection again.")
            return
        }
        state = .connecting

        do {
            let session = try await client.getSession(token: pendingToken, credentials: credentials)
            try store.set(session.key, for: Account.session)
            try store.set(session.username, for: Account.username)
            sessionKey = session.key
            self.pendingToken = nil
            state = .connected(username: session.username)
            activityMessage = "Last.fm is ready to scrobble."
        } catch {
            handle(error)
        }
    }

    func validateSession() async {
        guard let sessionKey, credentialsAreConfigured else { return }
        do {
            let username = try await client.getAuthenticatedUsername(
                sessionKey: sessionKey,
                credentials: credentials
            )
            try store.set(username, for: Account.username)
            state = .connected(username: username)
            activityMessage = "Last.fm authorization verified."
        } catch let apiError as LastFMAPIError where apiError.code == 9 {
            disconnect()
            state = .failed("Last.fm authorization expired. Connect again.")
        } catch {
            activityMessage = "Could not verify Last.fm right now."
        }
    }

    func disconnect() {
        store.delete(Account.session)
        store.delete(Account.username)
        sessionKey = nil
        pendingToken = nil
        state = .disconnected
        lastScrobble = nil
        activityMessage = "Disconnected from Last.fm."
    }

    func updateNowPlaying(_ track: TrackMetadata) {
        guard let sessionKey, credentialsAreConfigured else { return }
        let credentials = credentials
        Task {
            do {
                try await client.updateNowPlaying(
                    track: track,
                    sessionKey: sessionKey,
                    credentials: credentials
                )
                activityMessage = "Now playing sent to Last.fm."
            } catch {
                handleSubmissionError(error)
            }
        }
    }

    func scrobble(_ track: TrackMetadata, listenedAt: Date) {
        guard let sessionKey, credentialsAreConfigured else { return }
        let credentials = credentials
        Task {
            do {
                try await client.scrobble(
                    track: track,
                    listenedAt: listenedAt,
                    sessionKey: sessionKey,
                    credentials: credentials
                )
                lastScrobble = track.displayName
                activityMessage = "Scrobbled \(track.displayName)."
            } catch {
                handleSubmissionError(error)
            }
        }
    }

    private var credentials: LastFMCredentials {
        LastFMCredentials(apiKey: apiKey, sharedSecret: sharedSecret)
    }

    private func handle(_ error: Error) {
        if let apiError = error as? LastFMAPIError, apiError.code == 14 {
            state = .waitingForApproval
            activityMessage = "Approve access in Last.fm, then try again."
        } else if let apiError = error as? LastFMAPIError, apiError.code == 15 {
            pendingToken = nil
            state = .failed("The Last.fm approval expired. Start again.")
        } else if let apiError = error as? LastFMAPIError, apiError.code == 9 {
            disconnect()
            state = .failed("Last.fm authorization expired. Connect again.")
        } else {
            state = .failed(error.localizedDescription)
        }
    }

    private func handleSubmissionError(_ error: Error) {
        if let apiError = error as? LastFMAPIError, apiError.code == 9 {
            disconnect()
            state = .failed("Last.fm authorization expired. Connect again.")
        } else {
            activityMessage = "Last.fm did not accept the latest update."
        }
    }
}
