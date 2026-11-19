import XCTest

/// Finds a book from abroad on Open Library and shelves it. `-openLibraryStub YES`
/// answers every search with Halo, so the journey never touches the network. Search
/// needs the catalogue on the simulator, like the search journeys.
final class OpenLibraryJourneyTests: XCTestCase {
    @MainActor
    func testFindsABookFromAbroadAndShelvesIt() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-tasteQuizSeen", "YES",
                                "-inMemoryLibrary", "YES", "-openLibraryStub", "YES"]
        app.launch()

        app.tabBars.buttons["Search"].tap()
        if app.staticTexts["The catalogue isn't here yet"].waitForExistence(timeout: 2) {
            throw XCTSkip("No catalogue on this simulator")
        }
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText("Halo: The Fall of Reach")
        XCTAssertTrue(app.staticTexts["From Open Library"].waitForExistence(timeout: 5))
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Halo: The Fall of Reach'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No books found"].exists)
        attach("openlibrary-results", app)
        result.tap()

        XCTAssertTrue(app.staticTexts["Eric S. Nylund"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2001"].exists)
        // The stub's cover for Halo, credited under it.
        XCTAssertTrue(app.staticTexts["Cover: Open Library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Editions"].exists)
        XCTAssertFalse(app.buttons["Edit"].exists)
        attach("openlibrary-book", app)
        // Back in Search the answer is already known, so it shows at once.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(app.staticTexts["Searching Open Library…"].exists)
        XCTAssertTrue(result.exists)
        result.tap()
        XCTAssertTrue(app.buttons["Add to shelf"].waitForExistence(timeout: 5))
        app.buttons["Add to shelf"].tap()
        app.buttons["Reading"].tap()
        XCTAssertTrue(app.buttons["Shelf: Reading"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.links["See it on Open Library"].waitForExistence(timeout: 5))
        attach("openlibrary-book-shelved", app)

        app.tabBars.buttons["Shelves"].tap()
        let shelved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Halo: The Fall of Reach'")).firstMatch
        XCTAssertTrue(shelved.waitForExistence(timeout: 5))
        attach("openlibrary-shelves", app)
        shelved.tap()
        // Opened from the shelf, it is still the book from Open Library.
        XCTAssertTrue(app.buttons["Shelf: Reading"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.links["See it on Open Library"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSaysSoWhenOpenLibraryCantBeReached() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-tasteQuizSeen", "YES",
                                "-inMemoryLibrary", "YES", "-openLibraryStub", "YES"]
        app.launch()
        app.tabBars.buttons["Search"].tap()
        if app.staticTexts["The catalogue isn't here yet"].waitForExistence(timeout: 2) {
            throw XCTSkip("No catalogue on this simulator")
        }
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText("offline reading")
        XCTAssertTrue(app.staticTexts["Open Library can't be reached right now."].waitForExistence(timeout: 5))
        // Adding it by hand still works without the network.
        XCTAssertTrue(app.buttons["Can't find it? Add it yourself"].exists)
        attach("openlibrary-offline", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
