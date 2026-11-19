import Testing
@testable import Loe

@MainActor
struct WhereToGetItTests {
    private let library = Place.withID("ester.tlnrk.kannukuke")!
    private let catalogued = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull")
    private let byHand = CatalogueEdition(id: 0, erbID: "", title: "Halo: The Fall of Reach")

    @Test func esterIsAskedOnlyAboutABookItHasARecordOf() {
        #expect(WhereToGetIt.asksESTER(places: [library], editions: [catalogued]))
        #expect(!WhereToGetIt.asksESTER(places: [library], editions: [byHand]))
        #expect(!WhereToGetIt.asksESTER(places: [Place.apollo], editions: [catalogued]))
    }
}
