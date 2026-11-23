import XCTest

/// Opens the app on a library where two devices each shelved the same book.
/// Needs no catalogue.
final class DuplicateBooksJourneyTests: JourneyTestCase {
    @MainActor
    func testTwoRecordsOfOneBookBecomeOneThatKeepsItsRating() throws {
        let app = launch(Self.quizSeen + ["-duplicateBooks", "YES"])

        let covers = app.buttons.matching(NSPredicate(format: "label == 'Keisri hull'"))
        XCTAssertTrue(covers.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(covers.count, 1)
        attach("duplicates-merged", app)

        covers.firstMatch.tap()
        XCTAssertTrue(app.buttons["Shelf: Read"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["Rating"].value as? String, "5 of 5 stars")
    }
}
