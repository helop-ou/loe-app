import XCTest

/// A catalogue book with ESTER turned off, as the catalogue manifest can turn it:
/// no library is asked about, and the book has no cover or summary from ESTER.
/// `-asksESTER NO` stands in for what a manifest said. The journeys' ESTER would
/// answer every one of these, as the other journeys see.
final class ESTERSwitchJourneyTests: JourneyTestCase {
    @MainActor
    func testNothingIsAskedOfESTEROnceItIsTurnedOff() {
        let app = launch(JourneyTestCase.quizSeen + ["-asksESTER", "NO"])

        app.buttons["Settings"].tap()
        let add = app.buttons["Add a library or bookshop"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let search = app.searchFields["Find a library"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("kännu")
        app.buttons["Kännukuke"].tap()
        // An active search hides the toolbar until it is closed.
        app.buttons["close"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Kännukuke"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("ave maria")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ave Maria'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        // The page has loaded once its editions are there, and ESTER's cover and
        // summary would have come with them.
        XCTAssertTrue(app.staticTexts["Editions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cover: ESTER"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["From ESTER"].exists)
        attach("ester-off-book", app)

        // A shelf asks for the cover of the edition it holds, and now does not.
        app.buttons["Add to shelf"].tap()
        app.buttons["Want to read"].tap()
        XCTAssertTrue(app.buttons["Shelf: Want to read"].waitForExistence(timeout: 5))
        // Settings is still open on the Shelves tab, and tapping the selected tab
        // returns to its top.
        app.tabBars.buttons["Shelves"].tap()
        app.tabBars.buttons["Shelves"].tap()
        let shelved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ave Maria'")).firstMatch
        XCTAssertTrue(shelved.waitForExistence(timeout: 5))
        XCTAssertFalse(waitForESTERsCover(on: shelved, timeout: 3))
        attach("ester-off-shelf", app)
        shelved.tap()

        let heading = app.staticTexts["Where to get it"]
        for _ in 0..<4 where !heading.isHittable { app.swipeUp() }
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        // The library still opens the book's record, and says nothing of its copies.
        let library = app.links.matching(NSPredicate(format: "label CONTAINS 'Kännukuke'")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Opens in your browser. Choose your libraries and shops in Settings."].exists)
        for status in ["On the shelf", "Checking", "Couldn't check"] {
            XCTAssertFalse(library.label.contains(status), "The library row says \"\(library.label)\"")
        }
        attach("ester-off-where-to-get-it", app)
    }
}
