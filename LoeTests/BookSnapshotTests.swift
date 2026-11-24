import SwiftUI
import Testing
@testable import Loe

@MainActor
struct BookSnapshotTests {
    private static func edition(_ id: Int, _ year: Int, _ publisher: String, statement: String? = nil, pages: Int? = nil) -> CatalogueEdition {
        CatalogueEdition(
            id: id, erbID: "b1025334\(id)", title: "The czar's madman", subtitle: id == 1 ? nil : "a novel", authors: "Jaan Kross",
            translators: "Anselm Hollo; Ivo Iliste", year: year, publisher: publisher, language: "eng",
            originalTitle: "Keisri hull", originalLanguage: "est", editionStatement: statement, pages: pages, fiction: true
        )
    }

    // A translation the catalogue has no original for, with one edition more than
    // the list shows, and an edition with neither a statement nor a page count.
    private static let editions = [
        edition(1, 2003, "Harvill Press", statement: "Repr", pages: 352),
        edition(2, 1993, "Pantheon Books", pages: 348),
        edition(3, 1993, "Harvill", statement: "Repr", pages: 352),
        edition(4, 1993, "New Press", pages: 362),
        edition(5, 1992, "Harvill"),
        edition(6, 1992, "Harvill", pages: 352),
    ]

    @Test(arguments: Snapshot.Look.all)
    func aTranslationsHeaderOriginalAndEditions(look: Snapshot.Look) throws {
        let work = CatalogueWork(id: CatalogueWork.key(for: Self.editions[0]), editions: Self.editions)
        let page = VStack(alignment: .leading, spacing: 32) {
            BookHeader(work: work, edition: Self.editions[0], book: nil, art: nil, credit: false) { _ in }
            OriginalCard(edition: Self.editions[0], original: nil)
            EditionsSection(editions: Self.editions)
        }
        // A window, so a long publisher wraps at the largest text size as it does on the page.
        try Snapshot.verify(page.padding(20), named: "book", look: look, on: .window)
    }

    // A long description cut until asked for, and a short one that shows whole
    // with nothing to ask for. The text is Open Library's, so it stays as written.
    @Test(arguments: Snapshot.Look.all)
    func aBooksDescription(look: Snapshot.Look) throws {
        let long = """
            A teacher wakes up alone on a spaceship, far from home, with no memory of how he got there.

            Piece by piece he works out that he was sent to save the Earth, and that he may not be as alone as he \
            thought. It is a story of science, friendship and stubborn hope, told by a man who would much rather be \
            marking homework.
            """
        let descriptions = VStack(alignment: .leading, spacing: 32) {
            BookDescription(text: long)
            BookDescription(text: "A fox outwits three farmers who are tired of being robbed.")
        }
        try Snapshot.verify(descriptions.padding(20), named: "book-description", look: look, on: .window)
    }

    // Genres Loe names in English, and subjects that read as the bibliography has
    // them, enough of them to take a second row.
    @Test(arguments: Snapshot.Look.all)
    func aBooksTags(look: Snapshot.Look) throws {
        let tags = BookTagList(tags: [
            "biograafilised romaanid", "ajaloolised romaanid", "mälestused",
            "inimese evolutsioon", "Teine maailmasõda, 1939-1945", "kultuuriantropoloogia",
        ])
        // From the leading edge, as the page's column lays them out.
        try Snapshot.verify(
            tags.frame(maxWidth: .infinity, alignment: .leading).padding(20), named: "book-tags", look: look, on: .window
        )
    }
}
