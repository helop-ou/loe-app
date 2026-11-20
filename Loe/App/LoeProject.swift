import Foundation

/// Where Loe's code lives and how to reach its developer, as the About page and
/// Open Library see them.
nonisolated enum LoeProject {
    static let repository = URL(string: "https://github.com/helop-ou/loe-app")!
    static let issues = URL(string: "https://github.com/helop-ou/loe-app/issues")!
    static let contact = "support@helop.dev"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
