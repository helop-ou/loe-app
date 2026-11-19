import XCTest

/// Rates a book and follows what Read next suggests, on an in-memory library that
/// starts empty. Needs the catalogue on the simulator, like the search journeys.
final class ReadNextJourneyTests: XCTestCase {
    @MainActor
    func testSuggestsBooksFromAFavouriteAndKeepsOneForLater() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-inMemoryLibrary", "YES"]
        app.launch()

        app.tabBars.buttons["Read next"].tap()
        if app.staticTexts["Suggestions need the catalogue"].waitForExistence(timeout: 2) {
            attach("read-next-no-catalogue", app)
            throw XCTSkip("No catalogue on this simulator")
        }
        XCTAssertTrue(app.staticTexts["Nothing to suggest yet"].waitForExistence(timeout: 5))
        attach("read-next-empty", app)

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("kevade luts")
        let result = app.staticTexts["Kevade"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let add = app.buttons["Add to shelf"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["Read"].firstMatch.tap()
        let stars = app.otherElements["Rating"]
        XCTAssertTrue(stars.waitForExistence(timeout: 5))
        // The fifth of five evenly spaced stars.
        stars.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(stars.value as? String, "5 of 5 stars")

        app.tabBars.buttons["Read next"].tap()
        let reason = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '„Kevade“'")).firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 10))
        attach("read-next-suggestions", app)

        // The first suggestion goes to Want to read and leaves the list.
        let featured = app.buttons["featuredSuggestion"]
        XCTAssertTrue(featured.exists)
        let kept = featured.label
        app.buttons["Want to read"].tap()
        XCTAssertTrue(app.buttons["featuredSuggestion"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.buttons["featuredSuggestion"].label, kept)
        attach("read-next-kept", app)

        // On the shelf the cover is labelled with the title, which the card's label starts with.
        app.tabBars.buttons["Shelves"].tap()
        XCTAssertTrue(app.staticTexts["Want to read"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "%@ BEGINSWITH label", kept)).firstMatch.exists, kept)
        attach("read-next-shelves", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
