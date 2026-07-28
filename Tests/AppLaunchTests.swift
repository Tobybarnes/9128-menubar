import AppKit
import XCTest
@testable import Radio9128

@MainActor
final class AppLaunchTests: XCTestCase {
    private let firstLaunchKey = "com.tobybarnes.radio9128.hasShownBeta4Player"

    func testFirstLaunchShowsPlayerPopover() async throws {
        let (preferences, suiteName) = makeIsolatedPreferences()
        defer { preferences.removePersistentDomain(forName: suiteName) }

        var presentationCount = 0
        let delegate = AppDelegate(preferences: preferences) { _, _ in
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
        XCTAssertTrue(preferences.bool(forKey: firstLaunchKey))
    }

    func testFirstLaunchRetriesUntilPlayerPopoverCanBePresented() async throws {
        let (preferences, suiteName) = makeIsolatedPreferences()
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let playerWasPresented = expectation(description: "Player popover presented after status item became ready")
        var presentationCount = 0
        let delegate = AppDelegate(preferences: preferences) { _, _ in
            presentationCount += 1
            guard presentationCount == 3 else { return false }
            playerWasPresented.fulfill()
            return true
        }
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        await fulfillment(of: [playerWasPresented], timeout: 1)
        withExtendedLifetime(delegate) {}

        XCTAssertEqual(presentationCount, 3)
        XCTAssertTrue(preferences.bool(forKey: firstLaunchKey))
    }

    private func makeIsolatedPreferences() -> (UserDefaults, String) {
        let suiteName = "com.tobybarnes.radio9128.AppLaunchTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}
