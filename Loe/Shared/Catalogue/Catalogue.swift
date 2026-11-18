import Foundation

/// The offline copy of the National Bibliography. See docs/catalogue.md.
actor Catalogue {
    /// The schema this build reads. Must match `SCHEMA_VERSION` in tools/catalogue/build.py.
    static let schemaVersion = 1

    enum Failure: Error, Equatable {
        case unsupportedVersion(String?)
    }

    /// Everything the book page shows besides the work itself.
    struct Details: Sendable {
        /// Every edition of the work, newest first.
        var editions: [CatalogueEdition]
        /// The work this one was translated from, when the catalogue has it.
        var original: CatalogueWork?
        var translations: [CatalogueWork]
        var sameAuthor: [CatalogueWork]
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
        e.id, e.erb_id, e.title, e.subtitle, e.authors, e.translators, e.year, e.publisher, e.place,
        e.language, e.original_title, e.original_language, e.edition_statement, e.series,
        e.series_number, e.pages, e.fiction
        """
    private static let scoreColumn: Int32 = 17

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
        ) { row in (edition: Self.edition(row), score: row.double(Self.scoreColumn)) }
        return Array(CatalogueWork.ranked(hits, query: text).prefix(limit))
    }

    func details(for work: CatalogueWork) throws -> Details {
        let author = work.editions[0].leadAuthor
        let byAuthor = try author.map { try matching(CatalogueQuery.phrase($0, in: "authors"), limit: 3000) } ?? []
        let sameLead = byAuthor.filter { Self.sameAuthor($0.leadAuthor, author) }

        let editions = sameLead.filter { CatalogueWork.key(for: $0) == work.id }
        let translated = try matching(CatalogueQuery.phrase(work.title, in: "original_title"), limit: 500).filter {
            Self.sameTitle($0.originalTitle, work.title) && Self.sameAuthor($0.leadAuthor, author)
                && CatalogueWork.key(for: $0) != work.id
        }

        var original: CatalogueWork?
        if let originalTitle = work.editions.lazy.compactMap(\.originalTitle).first {
            let candidates = sameLead.filter { Self.sameTitle($0.title, originalTitle) && CatalogueWork.key(for: $0) != work.id }
            original = CatalogueWork.grouped(candidates).first
        }

        let related = Set([work.id] + (original.map { [$0.id] } ?? []))
        let translationKeys = Set(translated.map(CatalogueWork.key(for:)))
        let others = sameLead.filter {
            let key = CatalogueWork.key(for: $0)
            return !related.contains(key) && !translationKeys.contains(key) && $0.language == work.language
        }
        return Details(
            editions: (editions.isEmpty ? work.editions : editions).sorted { ($0.year ?? 0) > ($1.year ?? 0) },
            original: original,
            translations: CatalogueWork.grouped(translated),
            sameAuthor: Array(CatalogueWork.grouped(others).prefix(12))
        )
    }

    private func matching(_ expression: String?, limit: Int) throws -> [CatalogueEdition] {
        guard let expression else { return [] }
        return try database.rows(
            """
            SELECT \(Self.columns) FROM edition_search JOIN edition e ON e.id = edition_search.rowid
            WHERE edition_search MATCH ? LIMIT \(limit)
            """,
            [.text(expression)],
            map: Self.edition
        )
    }

    private static func sameTitle(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b else { return false }
        return CatalogueQuery.folded(a) == CatalogueQuery.folded(b)
    }

    private static func sameAuthor(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return CatalogueQuery.folded(a) == CatalogueQuery.folded(b)
    }

    private static func edition(_ row: SQLiteDatabase.Row) -> CatalogueEdition {
        CatalogueEdition(
            id: row.integer(0) ?? 0,
            erbID: row.text(1) ?? "",
            title: row.text(2) ?? "",
            subtitle: row.text(3),
            authors: row.text(4),
            translators: row.text(5),
            year: row.integer(6),
            publisher: row.text(7),
            place: row.text(8),
            language: row.text(9),
            originalTitle: row.text(10),
            originalLanguage: row.text(11),
            editionStatement: row.text(12),
            series: row.text(13),
            seriesNumber: row.text(14),
            pages: row.integer(15),
            fiction: row.integer(16) == 1
        )
    }
}
