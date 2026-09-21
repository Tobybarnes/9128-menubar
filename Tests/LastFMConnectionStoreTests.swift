import Foundation
import XCTest
@testable import Radio9128

final class LastFMConnectionStoreTests: XCTestCase {
    func testAuthorizedConnectionSurvivesABuildWithoutBundledConfiguration() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain()
        let original = try authorizedConnection()
        try makeStore(keychain, legacy).save(original)

        let restored = try makeStore(keychain, legacy).load(bundledConfiguration: nil)

        XCTAssertEqual(restored, original)
    }

    func testStoredCredentialsStayPairedWithSessionWhenBundleCredentialsChange() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain()
        let original = try authorizedConnection()
        try makeStore(keychain, legacy).save(original)

        let restored = try makeStore(keychain, legacy).load(
            bundledConfiguration: configuration(apiKey: "replacement-key", secret: "replacement-secret")
        )

        XCTAssertEqual(restored, original)
    }

    func testFirstConfiguredLaunchSavesCredentialsBeforeAnAccountIsConnected() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain()
        let configuration = try configuration()

        let initial = try makeStore(keychain, legacy).load(bundledConfiguration: configuration)
        let restored = try makeStore(keychain, legacy).load(bundledConfiguration: nil)

        XCTAssertEqual(initial?.configuration, configuration)
        XCTAssertNil(initial?.session)
        XCTAssertEqual(restored, initial)
    }

    func testMigratesLegacyAuthorizationWithItsBundledCredentials() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)
        let configuration = try configuration()

        let migrated = try makeStore(keychain, legacy).load(bundledConfiguration: configuration)
        let restored = try makeStore(keychain, legacy).load(bundledConfiguration: nil)

        XCTAssertEqual(migrated?.configuration, configuration)
        XCTAssertEqual(migrated?.session?.key, "legacy-session-key")
        XCTAssertEqual(migrated?.session?.username, "legacy-listener")
        XCTAssertEqual(restored, migrated)
        XCTAssertEqual(legacy.values, legacyAuthorization)
    }

    func testMissingConfigurationLeavesLegacyAuthorizationAvailableForLaterRepair() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)

        let connection = try makeStore(keychain, legacy).load(bundledConfiguration: nil)

        XCTAssertNil(connection)
        XCTAssertTrue(keychain.values.isEmpty)
        XCTAssertEqual(legacy.values, legacyAuthorization)
    }

    func testIncompleteLegacyAuthorizationDoesNotBecomeAConnectedAccount() throws {
        let incompleteRecords = [
            ["lastfm-session": "legacy-session-key"],
            ["lastfm-username": "legacy-listener"],
            ["lastfm-session": "", "lastfm-username": "legacy-listener"],
            ["lastfm-session": "legacy-session-key", "lastfm-username": " \n"],
        ]

        for record in incompleteRecords {
            let keychain = MemoryLastFMKeychain()
            let legacy = MemoryLastFMKeychain(values: record)
            let connection = try makeStore(keychain, legacy).load(bundledConfiguration: configuration())

            XCTAssertNotNil(connection?.configuration)
            XCTAssertNil(connection?.session, "An incomplete legacy record must not enable scrobbling.")
        }
    }

    func testStoredConnectionDoesNotDependOnReadingLegacyKeychain() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain()
        let original = try authorizedConnection()
        try makeStore(keychain, legacy).save(original)
        legacy.readError = .unavailable

        XCTAssertEqual(try makeStore(keychain, legacy).load(bundledConfiguration: nil), original)
    }

    func testReadFailureDoesNotReplaceAnExistingConnection() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain()
        let original = try authorizedConnection()
        try makeStore(keychain, legacy).save(original)
        let previousValues = keychain.values
        keychain.readError = .unavailable

        XCTAssertThrowsError(try makeStore(keychain, legacy).load(
            bundledConfiguration: configuration(apiKey: "replacement-key", secret: "replacement-secret")
        ))

        XCTAssertEqual(keychain.values, previousValues)
    }

    func testLegacyReadFailureDoesNotSaveAnIncompleteMigration() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)
        legacy.readError = .unavailable

        XCTAssertThrowsError(try makeStore(keychain, legacy).load(bundledConfiguration: configuration()))

        XCTAssertTrue(keychain.values.isEmpty)
        XCTAssertEqual(legacy.values, legacyAuthorization)
    }

    func testMigrationWriteFailurePreservesLegacyAuthorization() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)
        keychain.writeError = .unavailable

        XCTAssertThrowsError(try makeStore(keychain, legacy).load(bundledConfiguration: configuration()))

        XCTAssertTrue(keychain.values.isEmpty)
        XCTAssertEqual(legacy.values, legacyAuthorization)
    }

    func testSaveFailurePreservesTheLastSavedConnection() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain()
        let original = try authorizedConnection()
        try makeStore(keychain, legacy).save(original)
        keychain.writeError = .unavailable
        let replacement = LastFMConnection(
            configuration: try configuration(apiKey: "replacement-key", secret: "replacement-secret"),
            session: nil
        )

        XCTAssertThrowsError(try makeStore(keychain, legacy).save(replacement))
        keychain.writeError = nil

        XCTAssertEqual(try makeStore(keychain, legacy).load(bundledConfiguration: nil), original)
    }

    func testUnreadableSavedRecordIsNotOverwrittenByBundledCredentials() throws {
        let original = [LastFMConnectionStore.account: "not a saved connection"]
        let keychain = MemoryLastFMKeychain(values: original)
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)

        XCTAssertThrowsError(try makeStore(keychain, legacy).load(bundledConfiguration: configuration()))

        XCTAssertEqual(keychain.values, original)
        XCTAssertEqual(legacy.values, legacyAuthorization)
    }

    func testDisconnectRetainsConfigurationAndDoesNotRestoreLegacyAuthorization() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)
        let store = makeStore(keychain, legacy)
        let connection = try XCTUnwrap(store.load(bundledConfiguration: configuration()))

        let disconnected = try store.disconnect(connection)
        let restored = try makeStore(keychain, legacy).load(bundledConfiguration: nil)

        XCTAssertEqual(disconnected.configuration, connection.configuration)
        XCTAssertNil(disconnected.session)
        XCTAssertEqual(restored, disconnected)
        XCTAssertNil(legacy.values["lastfm-session"])
        XCTAssertNil(legacy.values["lastfm-username"])
    }

    func testFailedDisconnectSaveLeavesAuthorizationRecoverable() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)
        let store = makeStore(keychain, legacy)
        let connection = try XCTUnwrap(store.load(bundledConfiguration: configuration()))
        keychain.writeError = .unavailable

        XCTAssertThrowsError(try store.disconnect(connection))
        keychain.writeError = nil

        XCTAssertEqual(try store.load(bundledConfiguration: nil), connection)
        XCTAssertEqual(legacy.values, legacyAuthorization)
    }

    func testLegacyCleanupFailureCannotResurrectADisconnectedSession() throws {
        let keychain = MemoryLastFMKeychain()
        let legacy = MemoryLastFMKeychain(values: legacyAuthorization)
        let store = makeStore(keychain, legacy)
        let connection = try XCTUnwrap(store.load(bundledConfiguration: configuration()))
        legacy.deleteError = .unavailable

        let disconnected = try store.disconnect(connection)
        let restored = try makeStore(keychain, legacy).load(bundledConfiguration: nil)

        XCTAssertNil(disconnected.session)
        XCTAssertEqual(restored?.configuration, connection.configuration)
        XCTAssertNil(restored?.session)
    }

    private let legacyAuthorization = [
        "lastfm-session": "legacy-session-key",
        "lastfm-username": "legacy-listener",
    ]

    private func configuration(
        apiKey: String = "original-key",
        secret: String = "original-secret"
    ) throws -> LastFMConfiguration {
        try XCTUnwrap(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": apiKey,
            "LastFMSharedSecret": secret,
        ]))
    }

    private func authorizedConnection() throws -> LastFMConnection {
        LastFMConnection(
            configuration: try configuration(),
            session: LastFMSession(username: "listener", key: "session-key")
        )
    }

    private func makeStore(
        _ keychain: MemoryLastFMKeychain,
        _ legacy: MemoryLastFMKeychain
    ) -> LastFMConnectionStore {
        LastFMConnectionStore(store: keychain, legacyStore: legacy)
    }
}

final class MemoryLastFMKeychain: LastFMKeychainStoring {
    enum Failure: Error {
        case unavailable
    }

    var values: [String: String]
    var readError: Failure?
    var writeError: Failure?
    var deleteError: Failure?

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func string(for account: String) throws -> String? {
        if let readError { throw readError }
        return values[account]
    }

    func set(_ value: String, for account: String) throws {
        if let writeError { throw writeError }
        values[account] = value
    }

    func delete(_ account: String) throws {
        if let deleteError { throw deleteError }
        values.removeValue(forKey: account)
    }
}
