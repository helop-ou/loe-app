import Compression
import Foundation
import SQLite3
import Testing
@testable import Loe

/// Small catalogues built from the real tools/catalogue/schema.sql, so the app and
/// the build cannot drift apart unnoticed.
enum CatalogueFixture {
    private static let schema = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "tools/catalogue/schema.sql")

    static let manifest = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "tools/catalogue/manifest.json")

    static let standardBooks = """
        (1, 'b1', 'Tõde ja õigus', 'A. H. Tammsaare', 1926, 1, 0, NULL),
        (2, 'b2', 'Tõde ja õigus', 'A. H. Tammsaare', 2019, 1, 0, NULL),
        (3, 'b3', 'Pärsia kirjad', 'Montesquieu', 1966, 1, 0, 'Lettres persanes'),
        (4, 'b4', 'Õigus ja tõde', 'Rohke Debelakk', 2010, 0, 0, NULL)
        """

    static func make(
        version: Int = Catalogue.schemaVersion,
        books: String = standardBooks,
        at url: URL = URL.temporaryDirectory.appending(path: "catalogue-\(UUID().uuidString).sqlite")
    ) throws -> URL {
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let sql = try String(contentsOf: schema, encoding: .utf8) + """
            INSERT INTO meta VALUES ('schema_version', '\(version)');
            INSERT INTO edition (id, erb_id, title, authors, year, fiction, electronic, original_title) VALUES \(books);
            INSERT INTO isbn SELECT '9789949633289', id, 'köites' FROM edition WHERE erb_id = 'b3';
            INSERT INTO edition_search (rowid, title, authors, series, original_title)
              SELECT id, title, authors, series, original_title FROM edition;
            """
        try #require(
            sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK,
            Comment(rawValue: String(cString: sqlite3_errmsg(db)))
        )
        return url
    }

    /// The catalogue compressed the way the release ships it.
    static func xz(of url: URL) throws -> Data {
        var compressed = Data()
        let filter = try OutputFilter(.compress, using: .lzma) { data in
            if let data { compressed.append(data) }
        }
        try filter.write(try Data(contentsOf: url))
        try filter.finalize()
        return compressed
    }
}
