import XCTest

/// A journey through the real app. Every journey launches Loe through here, so
/// they all start the same way: in English on a light phone, on an empty
/// in-memory library, searching the small catalogue in `JourneyCatalogue`, and
/// off the network. See docs/standards.md, "Review and verification".
class JourneyTestCase: XCTestCase {
    /// Keeps the quiz away. A journey about the quiz passes its own.
    static let quizSeen = ["-tasteQuizSeen", "YES"]

    /// What the two journeys that can't do with a stand-in ask for.
    enum Real {
        /// The catalogue installed on the simulator, for the README screens.
        case catalogue
        /// The network and no catalogue yet, for the download.
        case download
    }

    /// Loe with what every journey passes it, not yet launched.
    @MainActor
    static func application(_ extra: [String] = quizSeen, real: Real? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-inMemoryLibrary", "YES"]
        if real != .download { app.launchArguments += ["-networkStub", "YES"] }
        if real == nil {
            switch JourneyCatalogue.file {
            case .success(let file): app.launchArguments += ["-catalogueFile", file.path]
            case .failure(let error): XCTFail("\(error)")
            }
        }
        app.launchArguments += extra
        return app
    }

    @MainActor
    func launch(_ extra: [String] = JourneyTestCase.quizSeen, real: Real? = nil) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
        let app = Self.application(extra, real: real)
        app.launch()
        return app
    }

    /// A journey that launches while the last one's Loe is still on its way out
    /// fails on a slow simulator, so each one ends with Loe gone.
    override func tearDown() async throws {
        await MainActor.run { Self.quit(XCUIApplication()) }
        try await super.tearDown()
    }

    @MainActor
    static func quit(_ app: XCUIApplication) {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 30))
    }

    @MainActor
    func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
