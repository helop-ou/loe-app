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
        #expect(BookView.coverArt(for: tode) == .ester(["b4659008", "b1210534"], title: "Tõde ja õigus"))
    }

    @Test func aBookEnteredByHandAsksForNothing() {
        let byHand = CatalogueWork(id: "hand:1", editions: [CatalogueEdition(id: 0, erbID: "", title: "Recipes")])
        #expect(BookView.coverArt(for: byHand) == nil)
    }

    /// Where books are listed, a cover shows when the phone has it. Lookups by ISBN
    /// are limited and ESTER is asked little, so a list asks only by cover id.
    @Test func aListAsksOnlyByCoverID() throws {
        let withCover = OpenLibraryBook(record: .init(workKey: "/works/OL1W", isbn: "9780345451323", coverID: 7), title: "Halo", authors: [])
        let withoutCover = OpenLibraryBook(record: .init(workKey: "/works/OL2W", isbn: "9780345451323"), title: "Halo", authors: [])
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        let byID = try #require(ListedCover.art(for: withCover.work))
        #expect(byID == .id(7))
        #expect(byID.isAskedForInLists)
        let byISBN = try #require(ListedCover.art(for: withoutCover.work))
        #expect(byISBN == .isbn("9780345451323"))
        #expect(!byISBN.isAskedForInLists)
        let esters = try #require(ListedCover.art(for: CatalogueWork(id: "k", editions: [kross])))
        #expect(esters == .ester(["b1054421"], title: "Keisri hull"))
        #expect(!esters.isAskedForInLists)
        let byHand = CatalogueWork(id: "hand:1", editions: [CatalogueEdition(id: 0, erbID: "", title: "Recipes")])
        #expect(ListedCover.art(for: byHand) == nil)
    }

    /// A page asks about its twelve newest editions. A shelf may hold an older
    /// one, so a list looks for a cover under every edition.
    @Test func aListLooksUnderEveryEdition() {
        let editions = (10...40).map { CatalogueEdition(id: $0, erbID: "b10000\($0)1", title: "Tõde ja õigus") }
        let tode = CatalogueWork(id: "tode", editions: editions)
        #expect(ListedCover.art(for: tode) == .ester((10...40).map { "b10000\($0)" }, title: "Tõde ja õigus"))
        #expect(BookView.coverArt(for: tode) == .ester((10...21).map { "b10000\($0)" }, title: "Tõde ja õigus"))
    }
}
