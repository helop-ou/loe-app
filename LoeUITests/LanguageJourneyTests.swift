import XCTest

/// Picking a language on first launch and changing it in Settings, on a phone set
/// to English. The choice is kept on the simulator, so each journey starts by
/// forgetting it and the class forgets it again when a journey ends, pass or fail:
/// every other journey reads Loe in English.
final class LanguageJourneyTests: JourneyTestCase {
    override func tearDown() async throws {
        await MainActor.run {
            Self.quit(XCUIApplication())
            Self.application(Self.quizSeen + ["-forgetLanguage", "YES"]).launch()
        }
        try await super.tearDown()
    }

    @MainActor
    func testTheFirstLaunchAsksForTheLanguageAndLoeKeepsIt() {
        let app = launch(["-tasteQuizSeen", "NO", "-forgetLanguage", "YES"])
        XCTAssertTrue(app.staticTexts["Eesti või English?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["The phone's language: English"].isSelected)
        attach("language-step", app)

        // The step itself turns Estonian, and so does everything after it.
        app.buttons["Eesti"].tap()
        XCTAssertTrue(app.buttons["Eesti"].isSelected)
        XCTAssertTrue(app.buttons["Telefoni keel: English"].waitForExistence(timeout: 5))
        attach("language-step-estonian", app)
        app.buttons["Edasi"].tap()
        XCTAssertTrue(app.staticTexts["Mida sulle meeldib lugeda?"].waitForExistence(timeout: 5))
        app.buttons["Jäta vahele"].tap()
        XCTAssertTrue(app.tabBars.buttons["Riiulid"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Riiulid"].exists)
        attach("shelves-estonian", app)

        // It is still Estonian the next time Loe opens, on a phone set to English.
        Self.quit(app)
        let again = launch([])
        XCTAssertTrue(again.tabBars.buttons["Riiulid"].waitForExistence(timeout: 5))
        XCTAssertFalse(again.staticTexts["Eesti või English?"].exists)
        again.tabBars.buttons["Otsi"].tap()
        XCTAssertTrue(again.navigationBars["Otsi"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsChangesTheLanguageAtOnce() {
        let app = launch(["-tasteQuizSeen", "YES", "-forgetLanguage", "YES"])
        app.buttons["Settings"].tap()
        // Named in both languages, whichever is showing.
        let phone = app.buttons["The phone's language: English"]
        scroll(app, to: phone)
        XCTAssertTrue(app.staticTexts["Language · Keel"].exists)
        XCTAssertTrue(phone.isSelected)

        app.buttons["Eesti"].tap()
        XCTAssertTrue(app.staticTexts["Keel · Language"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Eesti"].isSelected)
        // The screen that is up changes too, its title and the tabs under it.
        XCTAssertTrue(app.navigationBars["Seaded"].exists)
        XCTAssertTrue(app.tabBars.buttons["Riiulid"].exists)
        XCTAssertTrue(app.staticTexts["Välimus"].exists)
        attach("settings-estonian", app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Riiulid"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Riiulid on tühjad"].exists)

        // And back to the phone's own.
        app.buttons["Seaded"].tap()
        let telefon = app.buttons["Telefoni keel: English"]
        scroll(app, to: telefon)
        telefon.tap()
        XCTAssertTrue(app.staticTexts["Language · Keel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.buttons["The phone's language: English"].isSelected)
        XCTAssertTrue(app.tabBars.buttons["Shelves"].exists)
    }

    @MainActor
    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
