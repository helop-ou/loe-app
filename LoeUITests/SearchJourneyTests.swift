import XCTest

/// Searches the real catalogue. A simulator without one skips, so copy a built
/// catalogue into the app's container first (docs/catalogue.md, "Trying it in the simulator").
final class SearchJourneyTests: XCTestCase {
    @MainActor
    func testFindsABookByTitleWithoutDiacritics() throws {
        let app = try openSearch()
        search("keisri hull", in: app)
        XCTAssertTrue(app.staticTexts["Keisri hull"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Jaan Kross"].firstMatch.exists)
        attachScreenshot("search-results", of: app)
    }

    @MainActor
    func testSaysSoWhenNothingMatches() throws {
        let app = try openSearch()
        search("qqxxzzqq", in: app)
        XCTAssertTrue(app.staticTexts["No books found"].waitForExistence(timeout: 5))
        attachScreenshot("search-nothing", of: app)
    }

    @MainActor
    func testFindsABookByISBNAndSaysWhenOneIsMissing() throws {
        let app = try openSearch()
        search("978-9949-633-28-9", in: app)
        let field = app.searchFields.firstMatch
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        field.buttons["Clear text"].tap()
        field.typeText("0-306-40615-2")
        XCTAssertTrue(app.staticTexts["No book with this ISBN"].waitForExistence(timeout: 5))
        attachScreenshot("search-isbn-missing", of: app)
    }

    @MainActor
    func testOpensABookAndFollowsATranslation() throws {
        let app = try openSearch()
        search("keisri hull", in: app)
        let result = app.staticTexts["Keisri hull"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        XCTAssertTrue(app.staticTexts["Translations"].waitForExistence(timeout: 5))
        attachScreenshot("book-top", of: app)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Where to get it"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.links.matching(NSPredicate(format: "label CONTAINS 'ESTER'")).firstMatch.exists)
        attachScreenshot("book-scrolled", of: app)
        app.swipeDown()

        let translation = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'czar'")).firstMatch
        XCTAssertTrue(translation.waitForExistence(timeout: 2))
        translation.tap()
        XCTAssertTrue(app.staticTexts["Translated from Estonian"].waitForExistence(timeout: 5))
        attachScreenshot("book-translation", of: app)
    }

    @MainActor
    func testABookSuggestsSimilarBooks() throws {
        let app = try openSearch()
        search("kevade luts", in: app)
        let result = app.staticTexts["Kevade"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let similar = app.staticTexts["Similar books"]
        for _ in 0..<4 where !similar.isHittable { app.swipeUp() }
        XCTAssertTrue(similar.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'koolijutud'")).firstMatch.exists)
        attachScreenshot("book-similar", of: app)
    }

    /// Needs a catalogue served from the Mac and none on the simulator yet. See
    /// docs/catalogue.md, "Trying it in the simulator".
    @MainActor
    func testDownloadsTheCatalogue() throws {
        guard let manifest = ProcessInfo.processInfo.environment["LOE_CATALOGUE_MANIFEST"] else {
            throw XCTSkip("Set TEST_RUNNER_LOE_CATALOGUE_MANIFEST to a served manifest")
        }
        let app = launch(arguments: ["-catalogueManifestURL", manifest])
        app.tabBars.buttons["Search"].tap()
        let download = app.buttons["Download the catalogue"]
        guard download.waitForExistence(timeout: 3) else {
            throw XCTSkip("The catalogue is already on this simulator")
        }
        attachScreenshot("download-offer", of: app)
        download.tap()
        // From a server on the same Mac the download can finish before progress shows.
        if app.staticTexts["Downloading the catalogue"].waitForExistence(timeout: 1) {
            attachScreenshot("download-progress", of: app)
        }
        XCTAssertTrue(app.staticTexts["Find a book"].waitForExistence(timeout: 180))
        search("keisri hull", in: app)
        XCTAssertTrue(app.staticTexts["Keisri hull"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot("download-done", of: app)
    }

    @MainActor
    private func launch(arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func openSearch() throws -> XCUIApplication {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        if app.staticTexts["The catalogue isn't here yet"].waitForExistence(timeout: 2) {
            attachScreenshot("search-no-catalogue", of: app)
            throw XCTSkip("No catalogue on this simulator")
        }
        return app
    }

    @MainActor
    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
