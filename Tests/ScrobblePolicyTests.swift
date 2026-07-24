import XCTest
@testable import Radio9128

final class ScrobblePolicyTests: XCTestCase {
    func testUsesHalfTrackForThreeMinuteTracks() {
        XCTAssertEqual(ScrobblePolicy.requiredListenTime(trackDuration: 180), 90)
    }

    func testCapsLongAndUnknownTracksAtTwoMinutes() {
        XCTAssertEqual(ScrobblePolicy.requiredListenTime(trackDuration: 900), 120)
        XCTAssertEqual(ScrobblePolicy.requiredListenTime(trackDuration: nil), 120)
    }

    func testNeverScrobblesTracksShorterThanThirtySeconds() {
        XCTAssertNil(ScrobblePolicy.requiredListenTime(trackDuration: 29))
    }

    func testEligibleListenMustMeetThreshold() {
        XCTAssertFalse(ScrobblePolicy.shouldScrobble(listened: 89, trackDuration: 180))
        XCTAssertTrue(ScrobblePolicy.shouldScrobble(listened: 90, trackDuration: 180))
    }
}
