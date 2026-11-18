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
    private func openSearch() throws -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE"]
        app.launch()
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
