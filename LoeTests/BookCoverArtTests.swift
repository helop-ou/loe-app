import Foundation
import Testing
@testable import Loe

/// Which cover a book's page asks for.
struct BookCoverArtTests {
    @Test func aBookFromOpenLibraryAsksByCoverID() {
        let halo = OpenLibraryBook(record: .init(workKey: "/works/OL1W", isbn: "9780345451323", coverID: 7), title: "Halo", authors: [])
        #expect(BookView.coverArt(for: halo.work) == .id(7))
    }

    @Test func aBookFromOpenLibraryWithNoCoverIDAsksByISBN() {
        let halo = OpenLibraryBook(record: .init(workKey: "/works/OL1W", isbn: "9780345451323"), title: "Halo", authors: [])
        #expect(BookView.coverArt(for: halo.work) == .isbn("9780345451323"))
    }

    @Test func aCatalogueBookAsksESTERByItsEditionsInTheirOrder() {
        let tode = CatalogueWork(id: "tode", editions: [
            CatalogueEdition(id: 2, erbID: "b46590080", title: "Tõde ja õigus"),
            CatalogueEdition(id: 1, erbID: "b1210534x", title: "Tõde ja õigus"),
        ])
        #expect(BookView.coverArt(for: tode) == .ester(["b4659008", "b1210534"]))
    }

    @Test func aBookEnteredByHandAsksForNothing() {
        let byHand = CatalogueWork(id: "hand:1", editions: [CatalogueEdition(id: 0, erbID: "", title: "Recipes")])
        #expect(BookView.coverArt(for: byHand) == nil)
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
