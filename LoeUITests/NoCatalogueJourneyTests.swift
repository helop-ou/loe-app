import XCTest

/// Loe on a phone with no catalogue yet. Search is not a download screen: it
/// finds a book from abroad on Open Library, the book goes on a shelf, and a
/// notice says what the catalogue is doing. The journeys are off the network, so
/// here the download has failed.
final class NoCatalogueJourneyTests: JourneyTestCase {
    @MainActor
    func testShelvesABookFromAbroadWithNoCatalogue() {
        let app = launch(catalogue: Self.nowhere())

        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.staticTexts["The download didn't finish"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Try again"].exists)
        XCTAssertTrue(app.staticTexts["Find a book"].exists)
        attach("no-catalogue-search", app)

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Halo: The Fall of Reach")
        XCTAssertTrue(app.staticTexts["From Open Library"].waitForExistence(timeout: 5))
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Halo: The Fall of Reach'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        attach("no-catalogue-results", app)
        result.tap()

        let add = app.buttons["Add to shelf"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["Want to read"].tap()
        XCTAssertTrue(app.buttons["Shelf: Want to read"].waitForExistence(timeout: 5))
        // Where to get a book asks nothing of the catalogue.
        let heading = app.staticTexts["Where to get it"]
        for _ in 0..<4 where !heading.isHittable { app.swipeUp() }
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS 'Rahva Raamat'")).firstMatch.exists)
        attach("no-catalogue-book", app)

        app.tabBars.buttons["Shelves"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Halo'")).firstMatch.waitForExistence(timeout: 5))

        // A book nobody has can still be added by hand.
        app.tabBars.buttons["Search"].tap()
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        if field.buttons["Clear text"].exists { field.buttons["Clear text"].tap() }
        field.typeText("qqxxzzqq")
        XCTAssertTrue(app.buttons["Add it yourself"].waitForExistence(timeout: 5))
        attach("no-catalogue-nothing-found", app)
        // An active search covers the tab bar until it is closed.
        app.buttons["Close"].tap()

        app.tabBars.buttons["Read next"].tap()
        XCTAssertTrue(app.staticTexts["Suggestions need the catalogue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["The download didn't finish"].exists)
        attach("no-catalogue-read-next", app)
    }
}
