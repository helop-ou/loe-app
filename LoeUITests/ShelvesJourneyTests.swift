import XCTest

/// Shelves a book and tracks reading it, on an in-memory library that starts empty.
final class ShelvesJourneyTests: JourneyTestCase {
    @MainActor
    func testShelvesABookAndTracksReadingIt() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Your shelves are empty"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
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

        // A shelf's heading opens the whole shelf.
        app.buttons["Read, 1"].tap()
        XCTAssertTrue(app.navigationBars["Read"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Keisri hull'")).firstMatch.exists)
        attach("shelves-shelf", app)
    }

    /// A book shelved as read was finished today, until the reader says when.
    @MainActor
    func testSetsWhenABookWasRead() {
        let app = launch()

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("keisri hull")
        let result = app.staticTexts["Keisri hull"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let add = app.buttons["Add to shelf"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["Read"].firstMatch.tap()

        // Days as the journeys' region writes them, English in Estonia.
        let english = Locale(identifier: "en_EE")
        let long = Date.FormatStyle(date: .long, time: .omitted, locale: english)
        let today = Date.now
        let finished = app.staticTexts["Finished \(today.formatted(long))"]
        XCTAssertTrue(finished.waitForExistence(timeout: 5))

        app.buttons["Change dates"].tap()
        let addStart = app.buttons["Add a start date"]
        XCTAssertTrue(addStart.waitForExistence(timeout: 5))
        addStart.tap()
        // The first of this month, picked in the system's calendar, which offers
        // no day after today.
        let start = app.datePickers.element(boundBy: 0)
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let calendar = Calendar.current
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let month = first.formatted(.dateTime.month(.wide).locale(english))
        let day = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", 1. \(month)")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next Month"].isEnabled)
        day.tap()
        attach("shelves-reading-dates-calendar", app)
        app.buttons["PopoverDismissRegion"].tap()
        attach("shelves-reading-dates-sheet", app)
        app.buttons["Save"].tap()

        let started = app.staticTexts["Started \(first.formatted(long))"]
        XCTAssertTrue(started.waitForExistence(timeout: 5))
        XCTAssertTrue(finished.exists)
        attach("shelves-book-reading-dates", app)

        // Taking the finish away leaves the start.
        app.buttons["Change dates"].tap()
        let removeFinish = app.buttons["Remove the finish date"]
        XCTAssertTrue(removeFinish.waitForExistence(timeout: 5))
        removeFinish.tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(finished.waitForNonExistence(timeout: 5))
        XCTAssertTrue(started.exists)
    }

    /// A book that is only on a shelf has nothing of the reader's to lose, so
    /// removing it does not ask.
    @MainActor
    func testRemovesABookThatIsOnlyOnAShelfWithoutAsking() {
        let app = launch()

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("keisri hull")
        let result = app.staticTexts["Keisri hull"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        let add = app.buttons["Add to shelf"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["Want to read"].tap()

        let shelf = app.buttons["Shelf: Want to read"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        shelf.tap()
        app.buttons["Remove from shelves"].tap()
        XCTAssertTrue(app.buttons["Add to shelf"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Remove this book?"].exists)
    }

    /// Picks the newest picture in the simulator's Photos. A new simulator comes
    /// with a few.
    @MainActor
    func testGivesABookACoverPhoto() {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("keisri hull")
        app.staticTexts["Keisri hull"].firstMatch.tap()
        app.buttons["Add to shelf"].tap()
        app.buttons["Reading"].tap()

        let cover = app.buttons["Add a cover photo"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        cover.tap()
        app.buttons["Choose a photo"].tap()
        chooseTheNewestPhoto(in: app)

        XCTAssertTrue(app.buttons["Change the cover photo"].waitForExistence(timeout: 30))
        attach("cover-book", app)
        app.tabBars.buttons["Shelves"].tap()
        app.tabBars.buttons["Shelves"].tap()
        XCTAssertTrue(app.staticTexts["Keisri hull"].waitForExistence(timeout: 5))
        attach("cover-shelves", app)
    }
}
