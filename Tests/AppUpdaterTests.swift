import XCTest
@testable import Radio9128

@MainActor
final class AppUpdaterTests: XCTestCase {
    func testManualCheckRunsWhenSparkleIsReady() {
        var checkCount = 0
        let updater = AppUpdater(canCheckForUpdates: true) {
            checkCount += 1
        }

        updater.checkForUpdates()

        XCTAssertEqual(checkCount, 1)
    }

    func testManualCheckWaitsUntilSparkleIsReady() {
        var checkCount = 0
        let updater = AppUpdater(canCheckForUpdates: false) {
            checkCount += 1
        }

        updater.checkForUpdates()

        XCTAssertEqual(checkCount, 0)
    }
}
