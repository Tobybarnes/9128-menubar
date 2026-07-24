import XCTest
@testable import Radio9128

final class ScrobblePolicyTests: XCTestCase {
    func testUsesHalfTrackForTracksShorterThanEightMinutes() {
        XCTAssertEqual(ScrobblePolicy.requiredListenTime(trackDuration: 180), 90)
    }

    func testCapsThresholdAtFourMinutes() {
        XCTAssertEqual(ScrobblePolicy.requiredListenTime(trackDuration: 900), 240)
        XCTAssertEqual(ScrobblePolicy.requiredListenTime(trackDuration: nil), 240)
    }

    func testNeverScrobblesTracksShorterThanThirtySeconds() {
        XCTAssertNil(ScrobblePolicy.requiredListenTime(trackDuration: 29))
    }

    func testEligibleListenMustMeetThreshold() {
        XCTAssertFalse(ScrobblePolicy.shouldScrobble(listened: 89, trackDuration: 180))
        XCTAssertTrue(ScrobblePolicy.shouldScrobble(listened: 90, trackDuration: 180))
    }
}
