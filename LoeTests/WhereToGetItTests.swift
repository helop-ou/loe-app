import Testing
@testable import Loe

@MainActor
struct WhereToGetItTests {
    private let library = Place.withID("ester.tlnrk.kannukuke")!
    private let catalogued = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull")
    private let byHand = CatalogueEdition(id: 0, erbID: "", title: "Halo: The Fall of Reach")

    private let branch = Place.withID("ester.tlnrk.pelguranna")!

    private func rows(_ places: [Place], _ edition: CatalogueEdition) -> [WhereToGetItCard.Row] {
        let work = CatalogueWork(id: "w", editions: [edition])
        return WhereToGetIt.rows(places: places, work: work, edition: edition) { _ in .checking }
    }

    @Test func eachLibraryOpensTheBooksRecord() {
        let found = rows([library, Place.apollo, branch], catalogued)
        #expect(found.map(\.id) == [library.id, Place.apollo.id, branch.id])
        #expect(found[0].url.absoluteString == "https://www.ester.ee/record=b1054421")
        #expect(found[0].status == .checking)
    }

    @Test func aBookWithoutARecordIsSearchedForInsteadOfDisappearing() {
        // Libraries alone, as a reader may pick, used to leave a book from Open Library with nothing.
        let alone = rows([library, branch], byHand)
        #expect(alone.map(\.id) == ["ester"])
        let search = alone.first?.url
        #expect(search?.host() == "www.ester.ee")
        #expect(search?.query()?.contains("SEARCH=Halo") == true)
        #expect(alone.first?.status == nil)

        // The search stands where the first library was, and shops keep their place.
        #expect(rows([Place.apollo, library, branch, Place.rahvaRaamat], byHand).map(\.id)
            == [Place.apollo.id, "ester", Place.rahvaRaamat.id])
        // With nothing picked, ESTER still comes first.
        #expect(rows([], byHand).map(\.id) == ["ester", Place.rahvaRaamat.id, Place.apollo.id])
    }

    @Test func esterIsAskedOnlyAboutABookItHasARecordOf() {
        #expect(WhereToGetIt.asksESTER(places: [library], editions: [catalogued]))
        #expect(!WhereToGetIt.asksESTER(places: [library], editions: [byHand]))
        #expect(!WhereToGetIt.asksESTER(places: [Place.apollo], editions: [catalogued]))
    }
}
