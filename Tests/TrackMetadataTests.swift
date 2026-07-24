import XCTest
@testable import Radio9128

final class TrackMetadataTests: XCTestCase {
    func testParsesArtistAndTitleAtFirstSeparator() {
        let track = TrackMetadata.parse("Certain Creatures - Nyau Dust (tdel Rework)")

        XCTAssertEqual(track.artist, "Certain Creatures")
        XCTAssertEqual(track.title, "Nyau Dust (tdel Rework)")
    }

    func testFallsBackToStationForUnstructuredMetadata() {
        let track = TrackMetadata.parse("9128 interlude")

        XCTAssertEqual(track.artist, "9128")
        XCTAssertEqual(track.title, "9128 interlude")
    }

    func testBuildsBandcampSearchURLFromArtistAndTitle() {
        let track = TrackMetadata(artist: "Textural Being", title: "Sept")

        XCTAssertEqual(
            track.bandcampSearchURL?.absoluteString,
            "https://bandcamp.com/search?q=Textural%20Being%20Sept"
        )
    }
}
