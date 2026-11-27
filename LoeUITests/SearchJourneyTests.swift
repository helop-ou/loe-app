import XCTest

/// Searches the journeys' catalogue and opens what it finds. The download is the
/// one journey here that needs more: docs/catalogue.md, "Trying it in the simulator".
final class SearchJourneyTests: JourneyTestCase {
    @MainActor
    func testFindsABookByTitleWithoutDiacritics() {
        let app = openSearch()
        search("keisri hull", in: app)
        XCTAssertTrue(app.staticTexts["Keisri hull"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Jaan Kross"].firstMatch.exists)
        attach("search-results", app)
    }

    @MainActor
    func testSaysSoWhenNothingMatches() {
        let app = openSearch()
        search("qqxxzzqq", in: app)
        XCTAssertTrue(app.staticTexts["No books found"].waitForExistence(timeout: 5))
        attach("search-nothing", app)
    }

    @MainActor
    func testFindsABookByISBNAndSaysWhenOneIsMissing() {
        let app = openSearch()
        search("978-9949-633-28-9", in: app)
        let field = app.searchFields.firstMatch
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        field.buttons["Clear text"].tap()
        field.typeText("0-306-40615-2")
        XCTAssertTrue(app.staticTexts["No book with this ISBN"].waitForExistence(timeout: 5))
        attach("search-isbn-missing", app)
    }

    /// A result shows its card until the book's own page has found its cover.
    /// `-networkStub YES` gives ESTER a plain blue one for „Ave Maria“.
    @MainActor
    func testAResultShowsTheCoverItsPageFound() {
        let app = openSearch()
        search("ave maria", in: app)
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ave Maria'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        // Search asks ESTER nothing, so the result has only its card.
        sleep(1)
        XCTAssertFalse(showsESTERsCover(result))
        result.tap()
        XCTAssertTrue(app.staticTexts["Cover: ESTER"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForESTERsCover(on: result))
        attach("search-results-kept-cover", app)
    }

    @MainActor
    func testOpensABookAndFollowsATranslation() {
        let app = openSearch()
        search("keisri hull", in: app)
        let result = app.staticTexts["Keisri hull"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        XCTAssertTrue(app.staticTexts["Translations"].waitForExistence(timeout: 5))
        // What kind of book it is, in the catalogue's genres as English names them.
        let tags = NSPredicate(format: "label CONTAINS 'Historical novels' AND label CONTAINS 'Biographical novels'")
        XCTAssertTrue(app.descendants(matching: .any).matching(tags).firstMatch.waitForExistence(timeout: 5))
        attach("book-top", app)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Where to get it"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS 'ESTER'")).firstMatch.exists)
        attach("book-scrolled", app)
        app.swipeDown()

        let translation = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'czar'")).firstMatch
        XCTAssertTrue(translation.waitForExistence(timeout: 2))
        translation.tap()
        XCTAssertTrue(app.staticTexts["Translated from Estonian"].waitForExistence(timeout: 5))
        attach("book-translation", app)
    }

    @MainActor
    func testABookSuggestsSimilarBooks() {
        let app = openSearch()
        search("kevade luts", in: app)
        let result = app.staticTexts["Kevade"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let similar = app.staticTexts["Similar books"]
        for _ in 0..<4 where !similar.isHittable { app.swipeUp() }
        XCTAssertTrue(similar.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'koolijutud'")).firstMatch.exists)
        attach("book-similar", app)
    }

    /// Needs a catalogue served from the Mac. Loe keeps what it fetches in a
    /// folder of the journey's own, so the simulator's catalogue is left alone.
    /// See docs/catalogue.md, "Trying it in the simulator".
    @MainActor
    func testFetchesTheCatalogueWithoutBeingAsked() throws {
        guard let manifest = ProcessInfo.processInfo.environment["LOE_CATALOGUE_MANIFEST"] else {
            throw XCTSkip("Set TEST_RUNNER_LOE_CATALOGUE_MANIFEST to a served manifest")
        }
        let catalogue = Self.nowhere()
        addTeardownBlock { try? FileManager.default.removeItem(at: catalogue.deletingLastPathComponent()) }
        let app = launch(Self.quizSeen + ["-catalogueManifestURL", manifest], real: .download, catalogue: catalogue)
        app.tabBars.buttons["Search"].tap()
        // From a server on the same Mac the download can finish before the notice shows.
        let notice = app.staticTexts["Downloading the catalogue"]
        if notice.waitForExistence(timeout: 1) {
            attach("download-progress", app)
        }
        XCTAssertTrue(notice.waitForNonExistence(timeout: 180))
        XCTAssertFalse(app.staticTexts["The download didn't finish"].exists)
        XCTAssertTrue(FileManager.default.fileExists(atPath: catalogue.path))
        search("keisri hull", in: app)
        XCTAssertTrue(app.staticTexts["Keisri hull"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Downloading the catalogue"].exists)
        attach("download-done", app)
    }

    @MainActor
    private func openSearch() -> XCUIApplication {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        return app
    }

    @MainActor
    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }
}
