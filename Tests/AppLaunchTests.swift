import AppKit
import XCTest
@testable import Radio9128

@MainActor
final class AppLaunchTests: XCTestCase {
    private let firstLaunchKey = "com.tobybarnes.radio9128.hasShownFirstLaunchPlayer"

    func testFirstLaunchShowsPlayerPopover() async throws {
        UserDefaults.standard.removeObject(forKey: firstLaunchKey)
        defer { UserDefaults.standard.removeObject(forKey: firstLaunchKey) }

        var presentationCount = 0
        let delegate = AppDelegate { _, _ in
            presentationCount += 1
            return true
        }
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }

        XCTAssertEqual(presentationCount, 1)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: firstLaunchKey))
    }
}
