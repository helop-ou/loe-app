import XCTest

/// Picking libraries and bookshops in Settings, and the book page listing them, on
/// an in-memory library. The book page needs the catalogue on the simulator.
final class PlacesJourneyTests: XCTestCase {
    @MainActor
    func testPickedPlacesAreWhereToGetIt() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-tasteQuizSeen", "YES", "-inMemoryLibrary", "YES", "-openLibraryStub", "YES"]
        app.launch()

        app.buttons["Settings"].tap()
        let add = app.buttons["Add a library or bookshop"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let search = app.searchFields["Find a library"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("kännu")
        app.buttons["Kännukuke"].tap()
        XCTAssertTrue(app.buttons["Kännukuke"].isSelected)
        attach("places-picker", app)
        search.buttons["Clear text"].tap()
        search.typeText("tartu ülikooli")
        app.buttons["Tartu Ülikooli Raamatukogu"].tap()
        search.buttons["Clear text"].tap()
        search.typeText("apollo")
        app.buttons["Apollo"].tap()
        // An active search hides the toolbar until it is closed.
        app.buttons["close"].tap()
        app.buttons["Done"].tap()

        let kannukuke = app.staticTexts["Kännukuke"]
        XCTAssertTrue(kannukuke.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tartu Ülikooli Raamatukogu"].exists)
        XCTAssertTrue(app.staticTexts["Apollo"].exists)
        attach("places-settings", app)

        // Swipe the university library away. A full swipe up scrolls the long Settings
        // page too far, under the navigation bar, so drag the row to the middle instead.
        let tartu = app.staticTexts["Tartu Ülikooli Raamatukogu"]
        let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        middle.press(forDuration: 0.1, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: app.frame.midY - tartu.frame.midY)))
        tartu.swipeLeft()
        let remove = app.buttons["Remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.staticTexts["Tartu Ülikooli Raamatukogu"].waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Search"].tap()
        if app.staticTexts["The catalogue isn't here yet"].waitForExistence(timeout: 2) {
            throw XCTSkip("No catalogue on this simulator")
        }
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText("keisri hull")
        let result = app.staticTexts["Keisri hull"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let heading = app.staticTexts["Where to get it"]
        for _ in 0..<4 where !heading.isHittable { app.swipeUp() }
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let library = app.links.matching(NSPredicate(format: "label CONTAINS 'Kännukuke'")).firstMatch
        XCTAssertTrue(library.exists)
        XCTAssertTrue(library.label.contains("Tallinna Raamatukogud"))
        XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS 'Apollo'")).firstMatch.exists)
        XCTAssertFalse(app.links.matching(NSPredicate(format: "label CONTAINS 'Rahva Raamat'")).firstMatch.exists)
        XCTAssertFalse(app.links.matching(NSPredicate(format: "label CONTAINS 'Tartu Ülikooli'")).firstMatch.exists)
        // ESTER is asked as the page opens, so the library says what it has.
        let answered = NSPredicate(format: "label CONTAINS 'Kännukuke' AND NOT (label CONTAINS 'Checking') AND NOT (label CONTAINS 'check right now')")
        XCTAssertTrue(app.links.matching(answered).firstMatch.waitForExistence(timeout: 20))
        attach("places-book", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
