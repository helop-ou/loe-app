import Testing
@testable import Loe

/// What Search says once the catalogue has answered with nothing: the catalogue
/// comes first, then Open Library, and only then that there is no such book.
@MainActor
struct SearchTests {
    private let halo = OpenLibraryBook(record: .init(workKey: "/works/OL8048395W"), title: "Halo: The Fall of Reach", authors: ["Eric S. Nylund"])
    private let isbn = "978-0-345-45132-3"

    private func nothingFound(for text: String, _ online: SearchView.Online, inCatalogue results: [CatalogueWork] = []) -> SearchView.NothingFound? {
        SearchView.nothingFound(for: text, inCatalogue: results, online: online)
    }

    @Test func aBookInTheCatalogueIsSomething() {
        let edition = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        let found = [CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])]
        #expect(nothingFound(for: isbn, .notAsked, inCatalogue: found) == nil)
        #expect(nothingFound(for: "keisri hull", .found([]), inCatalogue: found) == nil)
    }

    @Test func nothingIsSaidWhileOpenLibraryIsStillAsked() {
        #expect(nothingFound(for: isbn, .searching) == nil)
        #expect(nothingFound(for: "halo", .searching) == nil)
    }

    @Test func aBookOnOpenLibraryIsSomething() {
        #expect(nothingFound(for: isbn, .found([halo])) == nil)
        #expect(nothingFound(for: "halo", .found([halo])) == nil)
    }

    @Test func theListSaysSoWhenOpenLibraryCantBeReached() {
        #expect(nothingFound(for: isbn, .failed) == nil)
    }

    @Test func anISBNNeitherHasIsNoBookWithThisISBN() {
        #expect(nothingFound(for: isbn, .found([])) == .isbn)
        #expect(nothingFound(for: "0-345-45132-5", .found([])) == .isbn)
    }

    @Test func anythingElseNeitherHasIsNoBooksFound() {
        #expect(nothingFound(for: "qqxxzzqq", .found([])) == .text)
        // Too short to ask Open Library about.
        #expect(nothingFound(for: "qq", .notAsked) == .text)
    }
}
