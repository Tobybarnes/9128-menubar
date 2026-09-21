import Foundation
import XCTest
@testable import Radio9128

@MainActor
final class LastFMManagerTests: XCTestCase {
    func testValidationSuccessAfterDisconnectDoesNotReconnectTheAccount() async throws {
        try await assertDisconnectedAfterDelayedValidation(
            responseJSON: #"{"user":{"name":"listener"}}"#
        )
    }

    func testExpiredSessionResponseAfterDisconnectDoesNotReplaceDisconnectedState() async throws {
        try await assertDisconnectedAfterDelayedValidation(
            responseJSON: #"{"error":9,"message":"Invalid session key"}"#
        )
    }

    private func assertDisconnectedAfterDelayedValidation(responseJSON: String) async throws {
        let configuration = try XCTUnwrap(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "test-api-key",
            "LastFMSharedSecret": "test-shared-secret",
        ]))
        let store = LastFMConnectionStore(
            store: MemoryLastFMKeychain(),
            legacyStore: MemoryLastFMKeychain()
        )
        try store.save(LastFMConnection(
            configuration: configuration,
            session: LastFMSession(username: "listener", key: "test-session-key")
        ))

        let requestStarted = expectation(description: "Validation request is waiting for its response")
        let response = HeldLastFMResponse(requestStarted: requestStarted)
        let requestID = UUID().uuidString
        HeldLastFMURLProtocol.responses.insert(response, for: requestID)
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [HeldLastFMURLProtocol.self]
        sessionConfiguration.httpAdditionalHeaders = ["X-LastFM-Test-ID": requestID]
        let session = URLSession(configuration: sessionConfiguration)
        defer {
            session.invalidateAndCancel()
            HeldLastFMURLProtocol.responses.remove(requestID)
        }

        let manager = LastFMManager(
            configuration: nil,
            store: store,
            client: LastFMClient(session: session)
        )
        let validation = Task { await manager.validateSession() }
        await fulfillment(of: [requestStarted], timeout: 2)

        manager.disconnect()
        XCTAssertEqual(manager.state, .disconnected)
        XCTAssertNil(try store.load(bundledConfiguration: nil)?.session)

        try response.complete(json: responseJSON)
        await validation.value

        XCTAssertEqual(manager.state, .disconnected)
        XCTAssertFalse(manager.isConnected)
        XCTAssertNil(try store.load(bundledConfiguration: nil)?.session)
    }
}

private final class HeldLastFMURLProtocol: URLProtocol, @unchecked Sendable {
    static let responses = HeldLastFMResponseRegistry()

    override class func canInit(with request: URLRequest) -> Bool {
        // Always intercept requests in this injected session, including malformed fixtures.
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestID = request.value(forHTTPHeaderField: "X-LastFM-Test-ID"),
              let response = Self.responses.response(for: requestID) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        response.hold(self)
    }

    override func stopLoading() {}
}

private final class HeldLastFMResponse: @unchecked Sendable {
    private let lock = NSLock()
    private var request: HeldLastFMURLProtocol?
    private let requestStarted: XCTestExpectation

    init(requestStarted: XCTestExpectation) {
        self.requestStarted = requestStarted
    }

    func hold(_ request: HeldLastFMURLProtocol) {
        lock.withLock { self.request = request }
        requestStarted.fulfill()
    }

    func complete(json: String) throws {
        let request = try XCTUnwrap(lock.withLock { self.request })
        let url = try XCTUnwrap(request.request.url)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ))
        request.client?.urlProtocol(request, didReceive: response, cacheStoragePolicy: .notAllowed)
        request.client?.urlProtocol(request, didLoad: Data(json.utf8))
        request.client?.urlProtocolDidFinishLoading(request)
        lock.withLock { self.request = nil }
    }
}

private final class HeldLastFMResponseRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: HeldLastFMResponse] = [:]

    func insert(_ response: HeldLastFMResponse, for requestID: String) {
        lock.withLock { values[requestID] = response }
    }

    func response(for requestID: String) -> HeldLastFMResponse? {
        lock.withLock { values[requestID] }
    }

    func remove(_ requestID: String) {
        lock.withLock { values[requestID] = nil }
    }
}
