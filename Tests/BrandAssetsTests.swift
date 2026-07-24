import XCTest
@testable import Radio9128

final class BrandAssetsTests: XCTestCase {
    func testMenuBarIconUsesNativeTemplateRendering() {
        XCTAssertTrue(BrandAssets.menuBarIcon.isTemplate)
    }
}
