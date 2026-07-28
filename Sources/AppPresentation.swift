import Foundation

enum AppPresentation {
    static let playerTitle = "9128.live"
    static let settingsTitle = "9128.live Player Settings"
    static let builderCredit = "built by Toby Barnes"

    static func versionLabel(infoDictionary: [String: Any]) -> String {
        let version = infoDictionary["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(version)"
    }
}
