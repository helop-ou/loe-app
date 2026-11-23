import XCTest

/// A journey through the real app. Every journey launches Loe through here, so
/// they all start the same way: in English, on an empty in-memory library, with
/// Open Library answered for. See docs/library.md, "Testing".
class JourneyTestCase: XCTestCase {
    /// Keeps the quiz away. A journey about the quiz passes its own.
    static let quizSeen = ["-tasteQuizSeen", "YES"]

    /// Loe with what every journey passes it, not yet launched.
    @MainActor
    static func application(_ extra: [String] = quizSeen) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-inMemoryLibrary", "YES", "-openLibraryStub", "YES"] + extra
        return app
    }

    @MainActor
    func launch(_ extra: [String] = JourneyTestCase.quizSeen) -> XCUIApplication {
        continueAfterFailure = false
        let app = Self.application(extra)
        app.launch()
        return app
    }

    @MainActor
    func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
