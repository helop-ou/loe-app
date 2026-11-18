import Foundation
import Testing
@testable import Loe

struct CatalogueTests {
    private func makeCatalogue(version: Int = Catalogue.schemaVersion) throws -> URL {
        try CatalogueFixture.make(version: version)
    }

    @Test func findsABookWithoutItsDiacritics() async throws {
        let catalogue = try Catalogue(url: makeCatalogue())
        let works = try await catalogue.search("tode ja oigus")
        #expect(works.first?.title == "Tõde ja õigus")
        #expect(works.first?.editions.count == 2)
    }

    @Test func findsABookByAnUnfinishedWord() async throws {
        let works = try await Catalogue(url: makeCatalogue()).search("tammsa")
        #expect(works.map(\.title) == ["Tõde ja õigus"])
    }

    @Test func findsATranslationByItsOriginalTitle() async throws {
        let works = try await Catalogue(url: makeCatalogue()).search("lettres persanes")
        #expect(works.map(\.title) == ["Pärsia kirjad"])
    }

    @Test func findsABookByISBN() async throws {
        let works = try await Catalogue(url: makeCatalogue()).search("978-9949-633-28-9")
        #expect(works.map(\.title) == ["Pärsia kirjad"])
    }

    @Test func refusesACatalogueFromAnotherSchema() throws {
        let url = try makeCatalogue(version: Catalogue.schemaVersion + 1)
        #expect(throws: Catalogue.Failure.unsupportedVersion(String(Catalogue.schemaVersion + 1))) {
            try Catalogue(url: url)
        }
    }

    @Test func theStoreSaysWhetherTheCatalogueIsThere() throws {
        let missing = CatalogueStore(url: URL.temporaryDirectory.appending(path: "nowhere.sqlite"))
        guard case .missing = missing.state else { Issue.record("expected missing"); return }
        let present = CatalogueStore(url: try makeCatalogue())
        guard case .ready = present.state else { Issue.record("expected ready"); return }
        let newer = CatalogueStore(url: try makeCatalogue(version: 99))
        guard case .unreadable = newer.state else { Issue.record("expected unreadable"); return }
    }
}
