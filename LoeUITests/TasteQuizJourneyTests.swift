import XCTest

/// The quiz on first launch, its answers in Read next, and changing them in Settings,
/// on an in-memory library. Read next needs the catalogue on the simulator.
final class TasteQuizJourneyTests: XCTestCase {
    @MainActor
    private func launch(firstTime: Bool) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-inMemoryLibrary", "YES"]
        // Launch arguments win over what the app saved, so only pass one to start fresh.
        if firstTime { app.launchArguments += ["-tasteQuizSeen", "NO"] }
        app.launch()
        return app
    }

    @MainActor
    func testSkippingTheQuizKeepsNothingAndItIsNotAskedAgain() {
        let app = launch(firstTime: true)
        XCTAssertTrue(app.staticTexts["What do you like to read?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Done"].isEnabled)
        app.buttons["Skip"].tap()
        XCTAssertFalse(app.staticTexts["What do you like to read?"].waitForExistence(timeout: 2))

        app.terminate()
        let again = launch(firstTime: false)
        XCTAssertTrue(again.tabBars.buttons["Shelves"].waitForExistence(timeout: 5))
        XCTAssertFalse(again.staticTexts["What do you like to read?"].waitForExistence(timeout: 2))
        again.buttons["Settings"].tap()
        XCTAssertTrue(again.staticTexts["Your tastes"].waitForExistence(timeout: 5))
        XCTAssertFalse(again.buttons["Crime and mystery"].isSelected)
    }

    @MainActor
    func testTastesFromTheQuizShapeReadNextAndChangeInSettings() throws {
        let app = launch(firstTime: true)
        XCTAssertTrue(app.staticTexts["What do you like to read?"].waitForExistence(timeout: 5))
        app.buttons["Crime and mystery"].tap()
        app.buttons["Fantasy"].tap()
        XCTAssertTrue(app.buttons["Crime and mystery"].isSelected)
        attach("quiz-picked", app)
        app.buttons["Done"].tap()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Your tastes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Crime and mystery"].isSelected)
        XCTAssertTrue(app.buttons["Fantasy"].isSelected)
        XCTAssertFalse(app.buttons["Romance"].isSelected)
        attach("settings-tastes", app)

        app.tabBars.buttons["Read next"].tap()
        if app.staticTexts["Suggestions need the catalogue"].waitForExistence(timeout: 2) {
            throw XCTSkip("No catalogue on this simulator")
        }
        let fantasy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'From your tastes: Fantasy'")).firstMatch
        XCTAssertTrue(fantasy.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'From your tastes: Crime and mystery'")).firstMatch.exists)
        attach("read-next-tastes", app)

        // Taking Fantasy out in Settings takes its suggestions out of Read next.
        app.tabBars.buttons["Shelves"].tap()
        app.buttons["Fantasy"].tap()
        XCTAssertFalse(app.buttons["Fantasy"].isSelected)
        app.tabBars.buttons["Read next"].tap()
        let crime = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'From your tastes: Crime and mystery'")).firstMatch
        XCTAssertTrue(crime.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'From your tastes: Fantasy'")).firstMatch.waitForNonExistence(timeout: 10))
        attach("read-next-one-taste", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
