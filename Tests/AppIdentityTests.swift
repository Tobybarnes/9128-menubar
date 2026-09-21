import XCTest
@testable import Radio9128

final class AppIdentityTests: XCTestCase {
    func testHostAppUsesStableFilenameAndPlayerDisplayName() {
        XCTAssertEqual(Bundle.main.bundleURL.lastPathComponent, "9128live_menubar_app.app")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "9128.live Player")
    }

    func testHostAppBundlesTheNextReleaseVersionAndBuild() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "1.0.1")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, "6")
    }

    func testHostAppDeclaresSecureSparkleFeed() throws {
        let feedURL = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        )
        let publicKey = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        )

        XCTAssertEqual(feedURL, "https://raw.githubusercontent.com/Tobybarnes/9128-menubar/main/appcast.xml")
        XCTAssertFalse(publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
