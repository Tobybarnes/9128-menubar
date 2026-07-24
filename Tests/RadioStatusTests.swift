import XCTest
@testable import Radio9128

final class RadioStatusTests: XCTestCase {
    func testDecodesRadioCoStatus() throws {
        let json = #"{"status":"online","current_track":{"title":"Textural Being - Sept","start_time":"2026-07-24T13:35:36+00:00","artwork_url":"https://example.com/100.jpg","artwork_url_large":"https://example.com/600.jpg"},"history":[{"title":"Textural Being - Sept"},{"title":"Atom TM - Friendly Cortex"}]}"#.data(using: .utf8)!

        let status = try RadioStatus.decoder.decode(RadioStatus.self, from: json)

        XCTAssertTrue(status.isOnline)
        XCTAssertEqual(status.currentTrack.metadata.artist, "Textural Being")
        XCTAssertEqual(status.currentTrack.metadata.title, "Sept")
        XCTAssertEqual(status.history.map(\.title), ["Textural Being - Sept", "Atom TM - Friendly Cortex"])
        XCTAssertNotNil(status.currentTrack.startedAt)
    }
}
