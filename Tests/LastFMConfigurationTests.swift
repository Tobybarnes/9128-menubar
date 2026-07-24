import XCTest
@testable import Radio9128

final class LastFMConfigurationTests: XCTestCase {
    func testLoadsDeveloperConfigurationFromBundleValues() {
        let configuration = LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": " developer-key ",
            "LastFMSharedSecret": " developer-secret ",
        ])

        XCTAssertEqual(configuration?.apiKey, "developer-key")
        XCTAssertEqual(configuration?.sharedSecret, "developer-secret")
    }

    func testRejectsMissingOrBlankDeveloperConfiguration() {
        XCTAssertNil(LastFMConfiguration(infoDictionary: [:]))
        XCTAssertNil(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "   ",
            "LastFMSharedSecret": "developer-secret",
        ]))
        XCTAssertNil(LastFMConfiguration(infoDictionary: [
            "LastFMAPIKey": "developer-key",
            "LastFMSharedSecret": "\n",
        ]))
    }
}
