import XCTest

/// Opens the app with a library that cannot be opened. Needs no catalogue.
final class LibraryUnavailableJourneyTests: XCTestCase {
    @MainActor
    func testShowsAScreenInsteadOfCrashingAndStaysOnItWhenTryingAgain() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-tasteQuizSeen", "YES", "-libraryCannotOpen", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your shelves can't be opened"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["Write to us"].exists)
        attach("library-unavailable", app)

        let tryAgain = app.buttons["Try again"]
        XCTAssertTrue(tryAgain.exists)
        tryAgain.tap()
        // The flag still makes opening fail, so the screen stays and the app is still running.
        XCTAssertTrue(app.staticTexts["Your shelves can't be opened"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
