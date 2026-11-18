import Foundation
import SQLite3
import Testing
@testable import Loe

/// Builds a small catalogue from the real tools/catalogue/schema.sql, so the app and
/// the build cannot drift apart unnoticed.
struct CatalogueTests {
    private static let schema = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "tools/catalogue/schema.sql")

    private func makeCatalogue(version: Int = Catalogue.schemaVersion) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "catalogue-\(UUID().uuidString).sqlite")
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let sql = try String(contentsOf: Self.schema, encoding: .utf8) + """
            INSERT INTO meta VALUES ('schema_version', '\(version)');
            INSERT INTO edition (id, erb_id, title, authors, year, fiction, electronic, original_title) VALUES
              (1, 'b1', 'Tõde ja õigus', 'A. H. Tammsaare', 1926, 1, 0, NULL),
              (2, 'b2', 'Tõde ja õigus', 'A. H. Tammsaare', 2019, 1, 0, NULL),
              (3, 'b3', 'Pärsia kirjad', 'Montesquieu', 1966, 1, 0, 'Lettres persanes'),
              (4, 'b4', 'Õigus ja tõde', 'Rohke Debelakk', 2010, 0, 0, NULL);
            INSERT INTO isbn VALUES ('9789949633289', 3, 'köites');
            INSERT INTO edition_search (rowid, title, authors, series, original_title)
              SELECT id, title, authors, series, original_title FROM edition;
            """
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, Comment(rawValue: String(cString: sqlite3_errmsg(db))))
        return url
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
