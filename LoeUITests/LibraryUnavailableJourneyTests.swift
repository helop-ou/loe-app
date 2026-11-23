import XCTest

/// Opens the app with a library that cannot be opened. Needs no catalogue.
final class LibraryUnavailableJourneyTests: JourneyTestCase {
    @MainActor
    func testShowsAScreenInsteadOfCrashingAndStaysOnItWhenTryingAgain() throws {
        let app = launch(Self.quizSeen + ["-libraryCannotOpen", "YES"])

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
}
