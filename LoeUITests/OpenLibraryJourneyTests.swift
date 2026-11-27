import XCTest

/// Finds a book from abroad on Open Library and shelves it. `-networkStub YES`
/// answers a search for Halo, by title or ISBN, with Halo, so the journey never
/// touches the network.
final class OpenLibraryJourneyTests: JourneyTestCase {
    @MainActor
    func testFindsABookFromAbroadAndShelvesIt() {
        let app = launch()

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
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

    /// A scan types the ISBN into Search, so typing it is the same journey.
    @MainActor
    func testFindsABookFromAbroadByItsISBN() {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("9780345451323")
        XCTAssertTrue(app.staticTexts["From Open Library"].waitForExistence(timeout: 5))
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Halo: The Fall of Reach'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No book with this ISBN"].exists)
        attach("openlibrary-isbn-result", app)
        result.tap()
        XCTAssertTrue(app.staticTexts["Eric S. Nylund"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // An ISBN neither the catalogue nor Open Library has.
        field.buttons["Clear text"].tap()
        field.typeText("9780306406157")
        XCTAssertTrue(app.staticTexts["No book with this ISBN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["It isn't in the catalogue or on Open Library. Try the title, or add the book yourself."].exists)
        XCTAssertTrue(app.buttons["Add it yourself"].exists)
        attach("openlibrary-isbn-nobody-has", app)
    }

    /// The catalogue has Project Hail Mary in Estonian, as „Ave Maria“.
    @MainActor
    func testABookFromAbroadLinksToItsEstonianTranslation() {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Project Hail Mary")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Project Hail Mary'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        XCTAssertTrue(app.staticTexts["Andy Weir"].waitForExistence(timeout: 5))
        // What the book is about, as Open Library has it, cut short until asked for.
        let description = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'A teacher wakes up alone'")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["From Open Library"].exists)
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Less"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Translations"].waitForExistence(timeout: 5))
        let translation = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ave Maria'")).firstMatch
        XCTAssertTrue(translation.waitForExistence(timeout: 2))
        attach("openlibrary-book-translations", app)
        // A row of covers asks ESTER nothing, so the translation has only its card.
        sleep(1)
        XCTAssertFalse(showsESTERsCover(translation))
        translation.tap()

        // The Estonian edition is the catalogue's, with its libraries and its ESTER record.
        XCTAssertTrue(app.staticTexts["Translated from English"].waitForExistence(timeout: 5))
        // ESTER has its cover and a summary of its own, each credited to it.
        XCTAssertTrue(app.staticTexts["Cover: ESTER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Õpetaja ärkab üksi'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["From ESTER"].exists)
        attach("openlibrary-translation", app)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Where to get it"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS 'ESTER'")).firstMatch.exists)

        // Back on the book from abroad, the row shows the cover that page found.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(translation.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForESTERsCover(on: translation))
        attach("openlibrary-book-translation-cover", app)

        // The author's other books are the catalogue's, in Estonian, and the page says so.
        let heading = app.staticTexts["By the same author, in Estonian"]
        for _ in 0..<4 where !heading.isHittable { app.swipeUp() }
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Marslane'")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Artemis'")).firstMatch.exists)
        attach("openlibrary-book-same-author", app)
    }

    @MainActor
    func testSaysSoWhenOpenLibraryCantBeReached() {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("offline reading")
        XCTAssertTrue(app.staticTexts["Open Library can't be reached right now."].waitForExistence(timeout: 5))
        // Adding it by hand still works without the network.
        XCTAssertTrue(app.buttons["Can't find it? Add it yourself"].exists)
        attach("openlibrary-offline", app)
    }
}
