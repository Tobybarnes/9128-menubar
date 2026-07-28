import Foundation

@MainActor
final class RadioService: ObservableObject {
    static let streamURL = URL(string: "https://streams.radio.co/s0aa1e6f4a/listen")!
    static let websiteURL = URL(string: "https://9128-live-player.vercel.app/")!
    private static let statusURL = URL(string: "https://public.radio.co/stations/s0aa1e6f4a/status")!

    @Published private(set) var status: RadioStatus?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    private var pollingTask: Task<Void, Never>?

    var currentTrack: RadioTrack? { status?.currentTrack }
    var recentTracks: [RadioHistoryItem] { Array((status?.history ?? []).dropFirst().prefix(5)) }
    var isOnline: Bool { status?.isOnline == true }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var components = URLComponents(url: Self.statusURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: components.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            status = try RadioStatus.decoder.decode(RadioStatus.self, from: data)
            errorMessage = nil
        } catch {
            errorMessage = "Track info is temporarily unavailable."
        }
    }
}
