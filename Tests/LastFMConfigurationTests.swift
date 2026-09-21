import XCTest
@testable import Radio9128

final class LastFMConfigurationTests: XCTestCase {
    func testLoadsDeveloperConfigurationFromBundleValues() {
        let configuration = LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": " developer-key ",
            "LastFMSharedSecret": " developer-secret ",
        ])

        XCTAssertEqual(configuration?.apiKey, "developer-key")
        XCTAssertEqual(configuration?.sharedSecret, "developer-secret")
    }

    func testRejectsMissingOrBlankDeveloperConfiguration() {
        XCTAssertNil(LastFMConfiguration(infoDictionary: [:]))
        XCTAssertNil(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "   ",
            "LastFMSharedSecret": "developer-secret",
        ]))
        XCTAssertNil(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "developer-key",
            "LastFMSharedSecret": "\n",
        ]))
    }

    func testRejectsUnexpandedBuildSettings() {
        XCTAssertNil(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "$(LASTFM_API_KEY)",
            "LastFMSharedSecret": "$(LASTFM_SHARED_SECRET)",
        ]))
    }

    @MainActor
    func testManagerRestoresAccountInABuildWithoutCredentials() throws {
        let configuration = try XCTUnwrap(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "developer-key",
            "LastFMSharedSecret": "developer-secret",
        ]))
        let store = LastFMConnectionStore(
            store: MemoryLastFMKeychain(),
            legacyStore: MemoryLastFMKeychain()
        )
        try store.save(LastFMConnection(
            configuration: configuration,
            session: LastFMSession(username: "listener", key: "session-key")
        ))

        let manager = LastFMManager(configuration: nil, store: store)

        XCTAssertEqual(manager.state, .connected(username: "listener"))
        XCTAssertTrue(manager.configurationIsAvailable)
        manager.disconnect()
        XCTAssertFalse(manager.isConnected)
        XCTAssertTrue(manager.configurationIsAvailable)
        XCTAssertNil(try store.load(bundledConfiguration: nil)?.session)
    }

    @MainActor
    func testManagerDoesNotReportDisconnectedIfSavingFails() throws {
        let keychain = MemoryLastFMKeychain()
        let store = LastFMConnectionStore(store: keychain, legacyStore: MemoryLastFMKeychain())
        let configuration = try XCTUnwrap(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "developer-key",
            "LastFMSharedSecret": "developer-secret",
        ]))
        try store.save(LastFMConnection(
            configuration: configuration,
            session: LastFMSession(username: "listener", key: "session-key")
        ))
        let manager = LastFMManager(configuration: nil, store: store)
        keychain.writeError = .unavailable

        manager.disconnect()

        XCTAssertTrue(manager.isConnected)
        XCTAssertNotNil(manager.activityMessage)
    }
}
