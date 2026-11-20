import XCTest

/// Opens the app on a library where two devices each shelved the same book.
/// Needs no catalogue.
final class DuplicateBooksJourneyTests: XCTestCase {
    @MainActor
    func testTwoRecordsOfOneBookBecomeOneThatKeepsItsRating() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-tasteQuizSeen", "YES",
            "-inMemoryLibrary", "YES", "-duplicateBooks", "YES",
        ]
        app.launch()

        let covers = app.buttons.matching(NSPredicate(format: "label == 'Keisri hull'"))
        XCTAssertTrue(covers.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(covers.count, 1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "duplicates-merged"
        attachment.lifetime = .keepAlways
        add(attachment)

        covers.firstMatch.tap()
        XCTAssertTrue(app.buttons["Shelf: Read"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["Rating"].value as? String, "5 of 5 stars")
    }
}
