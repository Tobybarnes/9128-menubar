import XCTest
@testable import Radio9128

final class LastFMSigningTests: XCTestCase {
    func testSignatureSortsKeysAndAppendsSharedSecret() {
        let signature = LastFMSigner.signature(
            parameters: ["method": "track.scrobble", "artist": "Björk", "api_key": "key"],
            sharedSecret: "secret"
        )

        XCTAssertEqual(signature, "b814e2b06cb791bfa98825390aeb6870")
    }

    func testFormEncodingEscapesValues() {
        let body = LastFMSigner.formEncoded(["artist": "A & B", "track": "One/Two"])

        XCTAssertEqual(body, "artist=A%20%26%20B&track=One%2FTwo")
    }
}
