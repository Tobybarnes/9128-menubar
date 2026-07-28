import XCTest
@testable import Radio9128

final class AppIdentityTests: XCTestCase {
    func testHostAppUsesDistributionName() {
        XCTAssertEqual(Bundle.main.bundleURL.lastPathComponent, "9128live_menubar_app.app")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "9128live_menubar_app")
    }

    func testHostAppBundlesBeta3VersionInformation() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "1.0.0")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, "3")
    }
}
