import Foundation

/// The offline copy of the National Bibliography. See docs/catalogue.md.
actor Catalogue {
    /// The schema this build reads. Must match `SCHEMA_VERSION` in tools/catalogue/build.py.
    static let schemaVersion = 1

    enum Failure: Error, Equatable {
        case unsupportedVersion(String?)
    }

    private let database: SQLiteDatabase

    init(url: URL) throws {
        database = try SQLiteDatabase(readOnly: url)
        let version = try database.rows("SELECT value FROM meta WHERE key = 'schema_version'") { $0.text(0) }.first ?? nil
        guard version == String(Self.schemaVersion) else {
            throw Failure.unsupportedVersion(version)
        }
    }

    private static let columns = """
        e.id, e.erb_id, e.title, e.subtitle, e.authors, e.year, e.publisher,
        e.original_title, e.series, e.series_number, e.fiction
        """

    func search(_ text: String, limit: Int = 50) throws -> [CatalogueWork] {
        if let isbn = CatalogueQuery.isbn13(text) {
            let editions = try database.rows(
                "SELECT \(Self.columns) FROM isbn JOIN edition e ON e.id = isbn.edition_id WHERE isbn.isbn13 = ?",
                [.text(isbn)],
                map: Self.edition
            )
            return CatalogueWork.ranked(editions.map { ($0, 0) }, query: text)
        }
        guard let match = CatalogueQuery.match(for: text) else { return [] }
        let hits = try database.rows(
            """
            SELECT \(Self.columns), bm25(edition_search, 10, 5, 1, 2) AS score
            FROM edition_search JOIN edition e ON e.id = edition_search.rowid
            WHERE edition_search MATCH ? ORDER BY score LIMIT 400
            """,
            [.text(match)]
        ) { row in (edition: Self.edition(row), score: row.double(11)) }
        return Array(CatalogueWork.ranked(hits, query: text).prefix(limit))
    }

    private static func edition(_ row: SQLiteDatabase.Row) -> CatalogueEdition {
        CatalogueEdition(
            id: row.integer(0) ?? 0,
            erbID: row.text(1) ?? "",
            title: row.text(2) ?? "",
            subtitle: row.text(3),
            authors: row.text(4),
            year: row.integer(5),
            publisher: row.text(6),
            originalTitle: row.text(7),
            series: row.text(8),
            seriesNumber: row.text(9),
            fiction: row.integer(10) == 1
        )
    }
}
