import SwiftUI
import Testing
@testable import Loe

@MainActor
struct ShelvesSnapshotTests {
    private static let shelved = Date(timeIntervalSince1970: 1_800_000_000)

    private static func book(_ title: String, by author: String, on shelf: Shelf, page: Int? = nil, of pages: Int? = nil) -> ShelvedBook {
        let edition = CatalogueEdition(id: 1, erbID: "", title: title, authors: author, language: "est")
        let book = ShelvedBook(edition: edition, workKey: CatalogueWork.key(for: edition), shelf: shelf, now: shelved)
        if let page { book.setPage(page, of: pages, now: shelved) }
        return book
    }

    // A book partway through and one not started, then two shelves, one of them
    // with more covers than fit across.
    private static let books = [
        book("Keisri hull", by: "Jaan Kross", on: .reading, page: 212, of: 352),
        book("Kevade", by: "Oskar Luts", on: .reading),
        book("Tõde ja õigus", by: "A. H. Tammsaare", on: .wantToRead),
        book("Rehepapp, ehk, November", by: "Andrus Kivirähk", on: .wantToRead),
        book("Mees, kes teadis ussisõnu", by: "Andrus Kivirähk", on: .wantToRead),
        book("Seitsmes rahukevad", by: "Viivi Luik", on: .wantToRead),
        book("Nukitsamees", by: "Oskar Luts", on: .read),
    ]

    @Test(arguments: Snapshot.Look.all)
    func booksBeingReadAndARowForEachShelf(look: Snapshot.Look) throws {
        let list = ShelvesList(books: Self.books) { _ in } openShelf: { _ in }
        // A window, for the progress bar and the rows of covers.
        try Snapshot.verify(list.padding(20), named: "shelves", look: look, on: .window)
    }
}
