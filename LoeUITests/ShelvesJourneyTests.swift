import XCTest

/// Shelves a book and tracks reading it, on an in-memory library that starts empty.
/// Needs the catalogue on the simulator, like the search journeys.
final class ShelvesJourneyTests: XCTestCase {
    @MainActor
    func testShelvesABookAndTracksReadingIt() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-tasteQuizSeen", "YES", "-inMemoryLibrary", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your shelves are empty"].waitForExistence(timeout: 5))
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

        let add = app.buttons["Add to shelf"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["Reading"].tap()

        let update = app.buttons["Update page"]
        XCTAssertTrue(update.waitForExistence(timeout: 5))
        update.tap()
        let page = app.textFields["Page you're on"]
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        page.tap()
        page.typeText("212")
        let pages = app.textFields["Pages in the book"]
        pages.tap()
        pages.typeText("352")
        attach("shelves-page-sheet", app)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["p. 212 of 352"].waitForExistence(timeout: 5))
        attach("shelves-book-reading", app)

        app.tabBars.buttons["Shelves"].tap()
        XCTAssertTrue(app.staticTexts["p. 212 of 352"].waitForExistence(timeout: 5))
        attach("shelves-reading", app)

        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Keisri hull'")).firstMatch.tap()
        let shelf = app.buttons["Shelf: Reading"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        shelf.tap()
        app.buttons["Read"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Shelf: Read"].waitForExistence(timeout: 5))

        let stars = app.otherElements["Rating"]
        XCTAssertTrue(stars.exists)
        // The fourth of five evenly spaced stars.
        stars.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()
        XCTAssertEqual(stars.value as? String, "4 of 5 stars")
        attach("shelves-book-read", app)

        // Tapping the selected tab returns to its top.
        app.tabBars.buttons["Shelves"].tap()
        XCTAssertTrue(app.staticTexts["Read"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["p. 212 of 352"].exists)
        attach("shelves-read", app)
    }

    /// Needs a cover photo as the newest picture in the simulator's Photos, added
    /// with `xcrun simctl addmedia <udid> cover.jpg`.
    @MainActor
    func testGivesABookACoverPhoto() throws {
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
        field.typeText("keisri hull")
        app.staticTexts["Keisri hull"].firstMatch.tap()
        app.buttons["Add to shelf"].tap()
        app.buttons["Reading"].tap()

        let cover = app.buttons["Add a cover photo"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        cover.tap()
        app.buttons["Choose a photo"].tap()
        // The photo picker runs in its own process, so its photos are not in the
        // app's tree. The newest photo is the first thumbnail, top left.
        Thread.sleep(forTimeInterval: 3)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.42)).tap()

        XCTAssertTrue(app.buttons["Change the cover photo"].waitForExistence(timeout: 10))
        attach("cover-book", app)
        app.tabBars.buttons["Shelves"].tap()
        app.tabBars.buttons["Shelves"].tap()
        XCTAssertTrue(app.staticTexts["Keisri hull"].waitForExistence(timeout: 5))
        attach("cover-shelves", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
