import Foundation

struct LastFMCredentials: Sendable {
    let apiKey: String
    let sharedSecret: String
}

struct LastFMSession: Sendable {
    let username: String
    let key: String
}

struct LastFMAPIError: LocalizedError, Sendable {
    let code: Int?
    let message: String

    var errorDescription: String? { message }
}

final class LastFMClient: @unchecked Sendable {
    private let session: URLSession
    private let endpoint = URL(string: "https://ws.audioscrobbler.com/2.0/")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getToken(credentials: LastFMCredentials) async throws -> String {
        let data = try await request(method: "auth.getToken", parameters: [:], credentials: credentials)
        let envelope = try JSONDecoder().decode(TokenEnvelope.self, from: data)
        return envelope.token
    }

    func getSession(token: String, credentials: LastFMCredentials) async throws -> LastFMSession {
        let data = try await request(
            method: "auth.getSession",
            parameters: ["token": token],
            credentials: credentials
        )
        let envelope = try JSONDecoder().decode(SessionEnvelope.self, from: data)
        return LastFMSession(username: envelope.session.name, key: envelope.session.key)
    }

    func getAuthenticatedUsername(
        sessionKey: String,
        credentials: LastFMCredentials
    ) async throws -> String {
        let data = try await request(
            method: "user.getInfo",
            parameters: ["sk": sessionKey],
            credentials: credentials
        )
        let envelope = try JSONDecoder().decode(UserEnvelope.self, from: data)
        return envelope.user.name
    }

    func updateNowPlaying(
        track: TrackMetadata,
        sessionKey: String,
        credentials: LastFMCredentials
    ) async throws {
        _ = try await request(
            method: "track.updateNowPlaying",
            parameters: ["artist": track.artist, "track": track.title, "sk": sessionKey],
            credentials: credentials
        )
    }

    func scrobble(
        track: TrackMetadata,
        listenedAt: Date,
        sessionKey: String,
        credentials: LastFMCredentials
    ) async throws {
        _ = try await request(
            method: "track.scrobble",
            parameters: [
                "artist": track.artist,
                "track": track.title,
                "timestamp": String(Int(listenedAt.timeIntervalSince1970)),
                "sk": sessionKey
            ],
            credentials: credentials
        )
    }

    private func request(
        method: String,
        parameters: [String: String],
        credentials: LastFMCredentials
    ) async throws -> Data {
        var signed = parameters
        signed["method"] = method
        signed["api_key"] = credentials.apiKey

        var body = signed
        body["api_sig"] = LastFMSigner.signature(
            parameters: signed,
            sharedSecret: credentials.sharedSecret
        )
        body["format"] = "json"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(LastFMSigner.formEncoded(body).utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LastFMAPIError(code: nil, message: "Last.fm could not be reached.")
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = object["error"] as? Int {
            throw LastFMAPIError(
                code: code,
                message: object["message"] as? String ?? "Last.fm returned error \(code)."
            )
        }
        return data
    }
}

private struct TokenEnvelope: Decodable {
    let token: String
}

private struct SessionEnvelope: Decodable {
    struct Session: Decodable {
        let name: String
        let key: String
    }

    let session: Session
}

private struct UserEnvelope: Decodable {
    struct User: Decodable {
        let name: String
    }

    let user: User
}
