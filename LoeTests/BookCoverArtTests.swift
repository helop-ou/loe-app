import Foundation
import Testing
@testable import Loe

/// Which cover a book's page asks Open Library for.
struct BookCoverArtTests {
    private func catalogue() throws -> Catalogue {
        try Catalogue(url: CatalogueFixture.make(headings: """
            INSERT INTO isbn SELECT '9789985000001', id, 'pdf' FROM edition WHERE erb_id = 'b1';
            INSERT INTO isbn SELECT '9789985000002', id, NULL FROM edition WHERE erb_id = 'b2';
            """))
    }

    @MainActor
    @Test func aBooksPageAsksForTheRightCover() async throws {
        let catalogue = try catalogue()
        let halo = OpenLibraryBook(record: .init(workKey: "/works/OL1W", isbn: "9780345451323", coverID: 7), title: "Halo", authors: [])
        #expect(await BookView.coverArt(for: halo.work, in: catalogue) == .id(7))
        let tode = CatalogueWork(id: "tode", editions: [
            CatalogueEdition(id: 1, erbID: "b1", title: "Tõde ja õigus"),
            CatalogueEdition(id: 2, erbID: "b2", title: "Tõde ja õigus"),
        ])
        #expect(await BookView.coverArt(for: tode, in: catalogue) == .isbn("9789985000002"))
        let byHand = CatalogueWork(id: "hand:1", editions: [CatalogueEdition(id: 0, erbID: "", title: "Recipes")])
        #expect(await BookView.coverArt(for: byHand, in: catalogue) == nil)
    }

    @Test func searchResultsAskOnlyByCoverID() {
        let withCover = OpenLibraryBook(record: .init(workKey: "/works/OL1W", isbn: "9780345451323", coverID: 7), title: "Halo", authors: [])
        let withoutCover = OpenLibraryBook(record: .init(workKey: "/works/OL2W", isbn: "9780345451323"), title: "Halo", authors: [])
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        #expect(SearchResultRow.art(for: withCover.work) == .id(7))
        #expect(SearchResultRow.art(for: withoutCover.work) == nil)
        #expect(SearchResultRow.art(for: CatalogueWork(id: "k", editions: [kross])) == nil)
    }
}
