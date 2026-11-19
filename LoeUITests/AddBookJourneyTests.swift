import XCTest

/// Adds a book the catalogue doesn't have, by hand, on an in-memory library that
/// starts empty. Search needs the catalogue on the simulator, like the search journeys.
final class AddBookJourneyTests: XCTestCase {
    @MainActor
    func testAddsABookByHandEditsItAndRemovesIt() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-tasteQuizSeen", "YES", "-inMemoryLibrary", "YES"]
        app.launch()

        app.tabBars.buttons["Search"].tap()
        if app.staticTexts["The catalogue isn't here yet"].waitForExistence(timeout: 2) {
            throw XCTSkip("No catalogue on this simulator")
        }
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText("Halo: The Fall of Reach")
        XCTAssertTrue(app.staticTexts["No books found"].waitForExistence(timeout: 5))
        attach("add-nothing-found", app)
        app.buttons["Add it yourself"].tap()

        // The form starts from what was searched for.
        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Halo: The Fall of Reach")
        let author = app.textFields["Author"]
        author.tap()
        author.typeText("Eric Nylund")
        let pages = app.textFields["Pages"]
        pages.tap()
        pages.typeText("400")
        attach("add-form", app)
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Halo: The Fall of Reach"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Eric Nylund"].exists)
        XCTAssertTrue(app.buttons["Shelf: Want to read"].exists)
        XCTAssertFalse(app.staticTexts["Editions"].exists)
        attach("add-book-page", app)

        app.buttons["Edit"].tap()
        let year = app.textFields["Year"]
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        year.tap()
        year.typeText("2001")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["2001"].waitForExistence(timeout: 5))
        attach("add-book-edited", app)

        app.tabBars.buttons["Shelves"].tap()
        let shelved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Halo: The Fall of Reach'")).firstMatch
        XCTAssertTrue(shelved.waitForExistence(timeout: 5))
        attach("add-shelves", app)
        shelved.tap()

        let shelf = app.buttons["Shelf: Want to read"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        shelf.tap()
        app.buttons["Remove from shelves"].tap()
        // The book was only on the shelves, so its page closes with it.
        XCTAssertTrue(app.staticTexts["Your shelves are empty"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
