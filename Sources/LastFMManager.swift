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

    @Published private(set) var state: ConnectionState
    @Published private(set) var lastScrobble: String?
    @Published private(set) var activityMessage: String?

    private let store: LastFMConnectionStore
    private var connection: LastFMConnection?
    private let client: LastFMClient
    private var pendingToken: String?

    private var sessionKey: String? { connection?.session?.key }

    init(
        configuration: LastFMConfiguration? = LastFMConfiguration(),
        store: LastFMConnectionStore = LastFMConnectionStore(),
        client: LastFMClient = LastFMClient()
    ) {
        self.store = store
        self.client = client
        state = .disconnected
        do {
            connection = try store.load(bundledConfiguration: configuration)
            if connection == nil {
                state = .failed("Last.fm setup is unavailable. Check for an app update.")
            } else if let session = connection?.session {
                state = .connected(username: session.username)
            }
        } catch {
            state = .failed("Could not open the saved Last.fm connection.")
            activityMessage = error.localizedDescription
        }
    }

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var configurationIsAvailable: Bool {
        connection != nil
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

    func connect() async {
        guard let credentials, let connection else {
            state = .failed("Last.fm setup is unavailable. Check for an app update.")
            return
        }
        state = .connecting
        activityMessage = nil

        do {
            let token = try await client.getToken(credentials: credentials)
            guard self.connection == connection else { return }
            pendingToken = token
            var components = URLComponents(string: "https://www.last.fm/api/auth/")!
            components.queryItems = [
                URLQueryItem(name: "api_key", value: credentials.apiKey),
                URLQueryItem(name: "token", value: token)
            ]
            guard let url = components.url else {
                throw LastFMAPIError(code: nil, message: "Could not create the Last.fm approval link.")
            }
            NSWorkspace.shared.open(url)
            state = .waitingForApproval
        } catch {
            guard self.connection == connection else { return }
            handle(error)
        }
    }

    func finishAuthorization() async {
        guard let pendingToken else {
            state = .failed("Start the Last.fm connection again.")
            return
        }
        guard let credentials, let connection else {
            state = .failed("Last.fm setup is unavailable. Check for an app update.")
            return
        }
        state = .connecting

        do {
            let session = try await client.getSession(token: pendingToken, credentials: credentials)
            guard self.pendingToken == pendingToken, self.connection == connection else { return }
            var authorized = connection
            authorized.session = session
            try store.save(authorized)
            self.connection = authorized
            self.pendingToken = nil
            state = .connected(username: session.username)
            activityMessage = "Last.fm is ready to scrobble."
        } catch {
            guard self.pendingToken == pendingToken, self.connection == connection else { return }
            handle(error)
        }
    }

    func validateSession() async {
        guard let sessionKey, let credentials, let connection else { return }
        do {
            let username = try await client.getAuthenticatedUsername(
                sessionKey: sessionKey,
                credentials: credentials
            )
            guard self.connection == connection else { return }
            var verified = connection
            verified.session = LastFMSession(username: username, key: sessionKey)
            try store.save(verified)
            self.connection = verified
            state = .connected(username: username)
            activityMessage = "Last.fm authorization verified."
        } catch let apiError as LastFMAPIError where apiError.code == 9 {
            guard self.connection == connection else { return }
            disconnect()
            state = .failed("Last.fm authorization expired. Connect again.")
        } catch {
            guard self.connection == connection else { return }
            activityMessage = "Could not verify Last.fm right now."
        }
    }

    func disconnect() {
        do {
            if let connection {
                self.connection = try store.disconnect(connection)
            }
        } catch {
            activityMessage = "Could not save the Last.fm disconnection. Please try again."
            return
        }
        pendingToken = nil
        state = .disconnected
        lastScrobble = nil
        activityMessage = "Disconnected from Last.fm."
    }

    func updateNowPlaying(_ track: TrackMetadata) {
        guard let sessionKey, let credentials, let connection else { return }
        Task {
            do {
                try await client.updateNowPlaying(
                    track: track,
                    sessionKey: sessionKey,
                    credentials: credentials
                )
                guard self.connection == connection else { return }
                activityMessage = "Now playing sent to Last.fm."
            } catch {
                guard self.connection == connection else { return }
                handleSubmissionError(error)
            }
        }
    }

    func scrobble(_ track: TrackMetadata, listenedAt: Date) {
        guard let sessionKey, let credentials, let connection else { return }
        Task {
            do {
                try await client.scrobble(
                    track: track,
                    listenedAt: listenedAt,
                    sessionKey: sessionKey,
                    credentials: credentials
                )
                guard self.connection == connection else { return }
                lastScrobble = track.displayName
                activityMessage = "Scrobbled \(track.displayName)."
            } catch {
                guard self.connection == connection else { return }
                handleSubmissionError(error)
            }
        }
    }

    private var credentials: LastFMCredentials? {
        guard let configuration = connection?.configuration else { return nil }
        return LastFMCredentials(apiKey: configuration.apiKey, sharedSecret: configuration.sharedSecret)
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
