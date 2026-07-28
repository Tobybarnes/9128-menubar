import XCTest
@testable import Radio9128

final class AppPresentationTests: XCTestCase {
    func testVersionLabelUsesPublicVersionWithoutInternalBuildNumber() {
        let label = AppPresentation.versionLabel(infoDictionary: [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "5",
        ])

        XCTAssertEqual(label, "Version 1.0")
    }

    func testPlayerAndSettingsUseThe9128LiveName() {
        XCTAssertEqual(AppPresentation.playerTitle, "9128.live")
        XCTAssertEqual(AppPresentation.settingsTitle, "9128.live Player Settings")
        XCTAssertEqual(AppPresentation.builderCredit, "built by Toby Barnes")
    }
}
