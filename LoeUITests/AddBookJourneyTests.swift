import XCTest

/// Adds a book the catalogue doesn't have, by hand, on an in-memory library that
/// starts empty.
final class AddBookJourneyTests: JourneyTestCase {
    @MainActor
    func testAddsABookByHandEditsItAndRemovesIt() {
        let app = launch()

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Recipes from Grandma Tiiu")
        XCTAssertTrue(app.staticTexts["No books found"].waitForExistence(timeout: 5))
        attach("add-nothing-found", app)
        app.buttons["Add it yourself"].tap()

        // The form starts from what was searched for.
        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Recipes from Grandma Tiiu")
        let author = app.textFields["Author"]
        author.tap()
        author.typeText("Tiiu Tamm")
        let pages = app.textFields["Pages"]
        pages.tap()
        pages.typeText("400")
        attach("add-form", app)
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Recipes from Grandma Tiiu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tiiu Tamm"].exists)
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
        let shelved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Recipes from Grandma Tiiu'")).firstMatch
        XCTAssertTrue(shelved.waitForExistence(timeout: 5))
        attach("add-shelves", app)
        shelved.tap()

        let shelf = app.buttons["Shelf: Want to read"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        shelf.tap()
        app.buttons["Remove from shelves"].tap()
        // A book entered by hand is the reader's own, so removing it asks first.
        XCTAssertTrue(app.staticTexts["Remove this book?"].waitForExistence(timeout: 5))
        // The dialog is a popover anchored to the button, closed by a tap outside it.
        app.otherElements["PopoverDismissRegion"].tap()
        XCTAssertTrue(app.staticTexts["Remove this book?"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Shelf: Want to read"].exists)

        app.buttons["Shelf: Want to read"].tap()
        app.buttons["Remove from shelves"].tap()
        XCTAssertTrue(app.staticTexts["Remove this book?"].waitForExistence(timeout: 5))
        attach("remove-book", app)
        app.buttons["Remove"].tap()
        XCTAssertTrue(app.staticTexts["Your shelves are empty"].waitForExistence(timeout: 5))
    }
}
