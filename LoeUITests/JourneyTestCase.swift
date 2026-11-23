import XCTest

/// A journey through the real app. Every journey launches Loe through here, so
/// they all start the same way: in English on a light phone, on an empty
/// in-memory library, and off the network. See docs/standards.md, "Review and verification".
class JourneyTestCase: XCTestCase {
    /// Keeps the quiz away. A journey about the quiz passes its own.
    static let quizSeen = ["-tasteQuizSeen", "YES"]

    /// Loe with what every journey passes it, not yet launched. Only the journey
    /// that downloads a catalogue from the Mac goes on the network.
    @MainActor
    static func application(_ extra: [String] = quizSeen, onTheNetwork: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-inMemoryLibrary", "YES"]
        app.launchArguments += onTheNetwork ? [] : ["-networkStub", "YES"]
        app.launchArguments += extra
        return app
    }

    @MainActor
    func launch(_ extra: [String] = JourneyTestCase.quizSeen, onTheNetwork: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
        let app = Self.application(extra, onTheNetwork: onTheNetwork)
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
