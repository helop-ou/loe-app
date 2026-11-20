import Foundation
import Testing
@testable import Loe

struct ShelvedIdentityTests {
    private static func catalogueWork(_ title: String, by author: String, records: [String]) -> CatalogueWork {
        let editions = records.enumerated().map { CatalogueEdition(id: $0.offset + 1, erbID: $0.element, title: title, authors: author) }
        return CatalogueWork(id: CatalogueWork.key(for: editions[0]), editions: editions)
    }

    private let kevade = ShelvedIdentity(workKey: "kevade|oskar luts", erbID: "b10544215", title: "Kevade", leadAuthor: "Oskar Luts")
    private let halo = ShelvedIdentity(
        workKey: "halo the fall of reach|eric s nylund", source: .openLibrary, openLibraryKey: "/works/OL18626W",
        title: "Halo: The Fall of Reach", leadAuthor: "Eric S. Nylund"
    )

    @Test func aCatalogueBookIsFoundByItsRecordWhenItsTitleAndAuthorHaveChanged() {
        let corrected = Self.catalogueWork("Kevade. Pildikesi koolipõlvest", by: "Luts, Oskar", records: ["b11453679", "b10544215"])
        #expect(kevade.match(corrected) == .record)
    }

    @Test func aBookFromOpenLibraryIsFoundByItsWorkWhenItsTitleHasChanged() {
        let renamed = OpenLibraryBook(record: .init(workKey: "/works/OL18626W"), title: "The Fall of Reach", authors: ["Eric Nylund"]).work
        #expect(halo.match(renamed) == .record)
    }

    @Test func theSameTitleAndAuthorsAreTheSameBookWithoutARecordInCommon() {
        #expect(kevade.match(Self.catalogueWork("Kevade", by: "Oskar Luts", records: ["b11453679"])) == .workKey)
    }

    @Test func anotherBookIsNotFound() {
        #expect(kevade.match(Self.catalogueWork("Suvi", by: "Oskar Luts", records: ["b10000002"])) == nil)
        let strike = OpenLibraryBook(record: .init(workKey: "/works/OL2W"), title: "Halo: First Strike", authors: ["Eric S. Nylund"]).work
        #expect(halo.match(strike) == nil)
    }

    /// Books from Open Library and books entered by hand have no catalogue record,
    /// which must not make them all one book.
    @Test func havingNoRecordIsNotARecordInCommon() {
        let noRecord = ShelvedIdentity(workKey: "suvi|oskar luts", title: "Suvi", leadAuthor: "Oskar Luts")
        let other = CatalogueWork(id: "talv|oskar luts", editions: [CatalogueEdition(id: 0, erbID: "", title: "Talv", authors: "Oskar Luts")])
        #expect(noRecord.match(other) == nil)
        #expect(halo.match(other) == nil)
    }

    @Test func theOtherSourcesCopyIsTheSameBook() {
        let inCatalogue = CatalogueEdition(id: 7, erbID: "b10000001", title: "Halo", subtitle: "The fall of reach", authors: "Eric Nylund")
        #expect(halo.match(CatalogueWork(id: CatalogueWork.key(for: inCatalogue), editions: [inCatalogue])) == .sameBook)
    }

    @Test func aBookEnteredByHandIsOnlyEverItself() {
        let entered = ShelvedIdentity(workKey: "hand:1", source: .hand, title: "Kevade", leadAuthor: "Oskar Luts")
        #expect(entered.match(Self.catalogueWork("Kevade", by: "Oskar Luts", records: ["b10544215"])) == nil)
        #expect(entered.match(CatalogueWork(id: "hand:1", editions: [CatalogueEdition(id: 0, erbID: "", title: "Kevade")])) == .workKey)
    }

    @Test func aRecordCountsBeforeATitleAndATitleBeforeTheOtherSourcesCopy() {
        #expect(ShelvedIdentity.Match.record > .workKey)
        #expect(ShelvedIdentity.Match.workKey > .sameBook)
    }
}
