import XCTest

/// Fills the shelves with real books from the catalogue and captures the README
/// screens. Runs only when asked, see docs/release.md, "README screens".
final class ReadmeScreensTests: JourneyTestCase {
    private struct Book {
        let query: String
        let title: String
        let shelf: String
        var stars = 0
    }

    private let books = [
        Book(query: "seitsmes rahukevad", title: "Seitsmes rahukevad", shelf: "Want to read"),
        Book(query: "kevade luts", title: "Kevade", shelf: "Want to read"),
        Book(query: "mees kes teadis ussisõnu", title: "Mees, kes teadis ussisõnu", shelf: "Want to read"),
        Book(query: "rehepapp ehk november kivirähk", title: "Rehepapp, ehk, November", shelf: "Read", stars: 4),
        Book(query: "tõde ja õigus", title: "Tõde ja õigus", shelf: "Read", stars: 5),
        Book(query: "keisri hull", title: "Keisri hull", shelf: "Reading"),
    ]

    @MainActor
    func testCapturesTheReadmeScreens() throws {
        guard ProcessInfo.processInfo.environment["LOE_README_SCREENS"] != nil else {
            throw XCTSkip("Set TEST_RUNNER_LOE_README_SCREENS=1 to capture the README screens")
        }
        let app = launch(real: .catalogue)
        app.tabBars.buttons["Search"].tap()
        if app.staticTexts["The catalogue isn't here yet"].waitForExistence(timeout: 2) {
            throw XCTSkip("No catalogue on this simulator")
        }

        for book in books {
            let field = app.searchFields.firstMatch
            field.tap()
            if field.buttons["Clear text"].exists { field.buttons["Clear text"].tap() }
            field.typeText(book.query)
            let result = app.staticTexts[book.title].firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 5), book.title)
            result.tap()
            let add = app.buttons["Add to shelf"]
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            add.tap()
            app.buttons[book.shelf].firstMatch.tap()
            if book.stars > 0 {
                let stars = app.otherElements["Rating"]
                XCTAssertTrue(stars.waitForExistence(timeout: 5))
                stars.coordinate(withNormalizedOffset: CGVector(dx: (Double(book.stars) - 0.5) / 5, dy: 0.5)).tap()
            }
            if book.title == "Keisri hull" { break }
            app.tabBars.buttons["Search"].tap()
        }

        // Keisri hull, being read, with a cover photo and its page in the cover's colour.
        app.buttons["Update page"].tap()
        let page = app.textFields["Page you're on"]
        page.tap()
        page.typeText("212")
        let pages = app.textFields["Pages in the book"]
        pages.tap()
        pages.typeText("352")
        app.buttons["Save"].tap()
        app.buttons["Add a cover photo"].tap()
        app.buttons["Choose a photo"].tap()
        Thread.sleep(forTimeInterval: 3)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.42)).tap()
        XCTAssertTrue(app.buttons["Change the cover photo"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        attach("readme-book", app)

        let translation = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'czar'")).firstMatch
        translation.tap()
        XCTAssertTrue(app.staticTexts["Translated from Estonian"].waitForExistence(timeout: 5))
        attach("readme-translation", app)

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        field.tap()
        field.buttons["Clear text"].tap()
        field.typeText("kivirähk")
        XCTAssertTrue(app.staticTexts["Andrus Kivirähk"].firstMatch.waitForExistence(timeout: 5))
        app.keyboards.buttons["search"].tap()
        Thread.sleep(forTimeInterval: 1)
        attach("readme-search", app)

        app.tabBars.buttons["Shelves"].tap()
        let reading = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'p. 212 of 352'")).firstMatch
        let shown = reading.waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 1)
        attach("readme-shelves", app)
        XCTAssertTrue(shown)
    }
}
