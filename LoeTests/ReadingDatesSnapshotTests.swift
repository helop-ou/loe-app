import SwiftUI
import Testing
@testable import Loe

@MainActor
struct ReadingDatesSnapshotTests {
    /// Noon in Greenwich, which is the same day in Tallinn and on CI.
    private static func day(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12))!
    }

    private static func book(on shelf: Shelf, started: Date? = nil, finished: Date? = nil) -> ShelvedBook {
        let edition = CatalogueEdition(id: 1, erbID: "", title: "Keisri hull", authors: "Jaan Kross", language: "est")
        let book = ShelvedBook(edition: edition, workKey: CatalogueWork.key(for: edition), shelf: shelf, now: day(25))
        book.startedAt = started
        book.finishedAt = finished
        return book
    }

    // A book being read, one that was read, and one on Read with no dates yet.
    @Test(arguments: Snapshot.Look.all)
    func whenABookWasStartedAndFinished(look: Snapshot.Look) throws {
        let rows = VStack(alignment: .leading, spacing: 28) {
            ReadingDatesRow(book: Self.book(on: .reading, started: Self.day(3)))
            ReadingDatesRow(book: Self.book(on: .read, started: Self.day(3), finished: Self.day(24)))
            ReadingDatesRow(book: Self.book(on: .read))
        }
        // A window, so the lines wrap at the largest text size as they do on the page.
        try Snapshot.verify(
            rows.frame(maxWidth: .infinity, alignment: .leading).padding(20), named: "reading-dates", look: look, on: .window
        )
    }
}
