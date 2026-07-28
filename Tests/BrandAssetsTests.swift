import XCTest
@testable import Radio9128

final class BrandAssetsTests: XCTestCase {
    func testMenuBarIconUsesNativeTemplateRendering() {
        XCTAssertTrue(BrandAssets.menuBarIcon.isTemplate)
    }

    func testMenuBarIconFillsStatusItemCanvas() throws {
        let representation = try XCTUnwrap(
            BrandAssets.menuBarIcon.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        )
        var minimumX = representation.pixelsWide
        var minimumY = representation.pixelsHigh
        var maximumX = -1
        var maximumY = -1

        for y in 0..<representation.pixelsHigh {
            for x in 0..<representation.pixelsWide {
                guard representation.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.01 else {
                    continue
                }
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }

        let visibleWidth = Double(maximumX - minimumX + 1) / Double(representation.pixelsWide)
        let visibleHeight = Double(maximumY - minimumY + 1) / Double(representation.pixelsHigh)

        XCTAssertGreaterThanOrEqual(visibleWidth, 0.85)
        XCTAssertGreaterThanOrEqual(visibleHeight, 0.85)
    }
}
