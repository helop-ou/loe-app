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
        var similar: [Suggestion] = []
    }

    /// A book to move on to, and the reason it was suggested: the subject heading,
    /// genre or series it shares.
    struct Suggestion: Sendable, Hashable {
        let work: CatalogueWork
        let reason: String
    }

    /// How strict similar books are. The catalogue's own headings are uneven, so a
    /// short list of solid matches beats a long one of guesses.
    struct SimilarityLimits: Sendable {
        /// Headings on more editions than this say too little, such as "romaanid".
        var maximumHeadingEditions = 4000
        /// Publisher series in this range. Broader ones mix everything together.
        var seriesEditions = 3...400
        var minimumScore = 4.0
        /// Fewer matches than this and the page shows none.
        var minimumWorks = 3
        var limit = 10

        static let standard = SimilarityLimits()
    }

    /// Format and nationality headings, which most fiction shares.
    static let genericHeadings: Set<String> = ["e-raamatud", "audioraamatud", "kogutud teosed", "ilukirjandus", "eesti"]

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

    /// The ISBN a work's cover is looked up by: the print ISBN of the edition the
    /// reader shelved, else of the newest edition that has one. The shelves and the
    /// book's page ask the same way, so they show the same cover.
    func coverISBN(for work: CatalogueWork, preferring erbID: String? = nil) throws -> String? {
        let editions = try editions(of: work).map(\.erbID)
        var seen: Set<String> = []
        return try printISBN(of: ([erbID].compactMap { $0 } + editions).filter { seen.insert($0).inserted })
    }

    /// The print ISBN of the first of these editions that has one, for finding its
    /// cover. E-book and PDF ISBNs, series ISBNs and ISBNs printed wrong on the book
    /// (`vale`, alone or after `köites`) would find another book's cover, or none.
    func printISBN(of erbIDs: [String]) throws -> String? {
        let asked = Array(erbIDs.filter { !$0.isEmpty }.prefix(12))
        guard !asked.isEmpty else { return nil }
        let rows = try database.rows(
            """
            SELECT e.erb_id, isbn.isbn13, isbn.qualifier FROM isbn JOIN edition e ON e.id = isbn.edition_id
            WHERE e.electronic = 0 AND e.erb_id IN (\(asked.map { _ in "?" }.joined(separator: ",")))
            """,
            asked.map { .text($0) }
        ) { row in (erbID: row.text(0) ?? "", isbn: row.text(1) ?? "", qualifier: row.text(2) ?? "") }
        let print = rows.filter { $0.qualifier.isEmpty || ($0.qualifier.hasPrefix("köites") && !$0.qualifier.contains("vale")) }
        for erbID in asked {
            if let found = print.first(where: { $0.erbID == erbID }) { return found.isbn }
        }
        return nil
    }

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

    func details(for work: CatalogueWork, similarity limits: SimilarityLimits = .standard) throws -> Details {
        let author = work.editions[0].leadAuthor
        let sameLead = try byLeadAuthor(author)

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

        // A book opened from a shelf knows its title and authors but not its language.
        let language = (editions.first ?? work.editions[0]).language
        let related = Set([work.id] + (original.map { [$0.id] } ?? []))
        let translationKeys = Set(translated.map(CatalogueWork.key(for:)))
        let others = sameLead.filter {
            let key = CatalogueWork.key(for: $0)
            return !related.contains(key) && !translationKeys.contains(key) && $0.language == language
        }
        let allEditions = (editions.isEmpty ? work.editions : editions).sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        return Details(
            editions: allEditions,
            original: original,
            translations: CatalogueWork.grouped(translated),
            sameAuthor: Array(CatalogueWork.grouped(others).prefix(12)),
            similar: try similar(to: CatalogueWork(id: work.id, editions: allEditions), limits: limits)
        )
    }

    /// Every edition of the work, newest first. A book opened from a shelf starts with
    /// only the edition that was shelved.
    func editions(of work: CatalogueWork) throws -> [CatalogueEdition] {
        let first = work.editions[0]
        let found = try first.leadAuthor.map { try byLeadAuthor($0) }
            ?? matching(CatalogueQuery.phrase(first.title, in: "title"), limit: 3000)
        let editions = found.filter { CatalogueWork.key(for: $0) == work.id }
        return (editions.isEmpty ? work.editions : editions).sorted { ($0.year ?? 0) > ($1.year ?? 0) }
    }

    /// Fiction in one language under any of these genre or subject headings, the most
    /// often published first. How Read next finds books for the reader's tastes.
    func works(withHeadings names: [String], language: String, limit: Int) throws -> [CatalogueWork] {
        guard !names.isEmpty else { return [] }
        let editions = try database.rows(
            """
            SELECT \(Self.columns) FROM edition e WHERE e.fiction = 1 AND e.language = ? AND e.id IN (
              SELECT eh.edition_id FROM edition_heading eh JOIN heading h ON h.id = eh.heading_id
              WHERE h.name IN (\(Self.placeholders(names.count))))
            """,
            [.text(language)] + names.map { .text($0) },
            map: Self.edition
        )
        return Array(CatalogueWork.grouped(editions).prefix(limit))
    }

    /// The book that comes after this one, and the series they share.
    struct SeriesNext: Sendable, Hashable {
        let work: CatalogueWork
        /// The series as the editions name it, or the title the parts share.
        let series: String

        func contains(_ other: CatalogueWork) -> Bool {
            let folded = CatalogueQuery.folded(series)
            return other.editions.contains {
                $0.series == series || Catalogue.part(of: $0.title).map { CatalogueQuery.folded($0.base) == folded } == true
            }
        }
    }

    /// The next book in a series by this book's author, in its language: the next
    /// number in a series mostly by that author, or the next part of a book published
    /// in parts, such as „Tõde ja õigus. II jagu“. Publisher series that mix many
    /// authors are not series in this sense. Pass the work with all its editions.
    func nextInSeries(after work: CatalogueWork) throws -> SeriesNext? {
        let first = work.editions[0]
        let author = first.leadAuthor
        var seen: Set<String> = []
        for edition in work.editions {
            guard let series = edition.series, let number = Self.leadingNumber(edition.seriesNumber),
                  seen.insert(series).inserted
            else { continue }
            let members = try matching(CatalogueQuery.phrase(series, in: "series"), limit: 2000).filter { $0.series == series }
            let own = members.filter { Self.sameAuthor($0.leadAuthor, author) }.count
            // Mostly the author's own, which lets a play or a companion book by others in.
            guard members.count > 1, Double(own) >= 0.7 * Double(members.count) else { continue }
            let later = members.compactMap { member -> (edition: CatalogueEdition, number: Int)? in
                guard member.language == first.language, CatalogueWork.key(for: member) != work.id,
                      let number = Self.leadingNumber(member.seriesNumber)
                else { return nil }
                return (member, number)
            }
            .filter { $0.number > number }
            guard let next = later.map(\.number).min(),
                  let found = CatalogueWork.grouped(later.filter { $0.number == next }.map(\.edition)).first
            else { continue }
            return SeriesNext(work: found, series: series)
        }
        for edition in work.editions {
            guard let part = Self.part(of: edition.title), seen.insert(part.base).inserted else { continue }
            let base = CatalogueQuery.folded(part.base)
            let candidates = try matching(CatalogueQuery.phrase(part.base, in: "title"), limit: 3000).filter {
                guard Self.sameAuthor($0.leadAuthor, author), $0.language == first.language,
                      let other = Self.part(of: $0.title)
                else { return false }
                return CatalogueQuery.folded(other.base) == base && other.number == part.number + 1
            }
            if let found = CatalogueWork.grouped(candidates).first {
                return SeriesNext(work: found, series: part.base)
            }
        }
        return nil
    }

    /// The number a series number starts with: "2. raamat" is 2.
    nonisolated static func leadingNumber(_ text: String?) -> Int? {
        text.flatMap { Int($0.prefix { $0.isASCII && $0.isNumber }) }
    }

    private nonisolated static let ordinals = [
        "esimene", "teine", "kolmas", "neljas", "viies", "kuues", "seitsmes", "kaheksas", "uheksas", "kumnes",
    ]

    /// A title with a part number after its first full stop: „Tõde ja õigus. II jagu“,
    /// „Sõrmuste Isand. 2. osa. Kaks kantsi“, „Sõrmuste Isand. Teine osa“.
    nonisolated static func part(of title: String) -> (base: String, number: Int)? {
        guard let stop = title.range(of: ". ") else { return nil }
        let base = String(title[..<stop.lowerBound])
        let rest = title[stop.upperBound...]
        let token = String(rest.prefix { $0 != " " && $0 != "." })
        let after = rest.dropFirst(token.count)
        let number: Int?
        if let arabic = Int(token), token.allSatisfy(\.isASCII) {
            number = after.hasPrefix(".") ? arabic : nil
        } else if let roman = romanNumber(token) {
            number = after.isEmpty || after.hasPrefix(" ") || after.hasPrefix(".") ? roman : nil
        } else {
            number = ordinals.firstIndex(of: CatalogueQuery.folded(token)).map { $0 + 1 }
        }
        guard let number, number > 0, !base.isEmpty else { return nil }
        return (base, number)
    }

    private nonisolated static func romanNumber(_ token: String) -> Int? {
        let values: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50]
        guard !token.isEmpty, token.count <= 6 else { return nil }
        var total = 0
        var previous = 0
        for character in token.reversed() {
            guard let value = values[character] else { return nil }
            total += value < previous ? -value : value
            previous = max(previous, value)
        }
        return total
    }

    /// Every edition whose first author is this one.
    private func byLeadAuthor(_ author: String?) throws -> [CatalogueEdition] {
        guard let author else { return [] }
        return try matching(CatalogueQuery.phrase(author, in: "authors"), limit: 3000).filter { Self.sameAuthor($0.leadAuthor, author) }
    }

    /// Books like this one by other authors, from what the bibliography says about
    /// them: subject headings and genres that most of this work's editions carry,
    /// and narrow publisher series. A rarer shared heading counts for more, and a
    /// book published often ranks higher.
    func similar(to work: CatalogueWork, limits: SimilarityLimits = .standard) throws -> [Suggestion] {
        let ids = work.editions.map(\.id).filter { $0 > 0 }
        guard !ids.isEmpty else { return [] }
        let total = Double(try editionCount())
        var signals: [(reason: String, weight: Double, editions: [Int])] = []

        let headings = try database.rows(
            """
            SELECT h.id, h.name, COUNT(*) FROM edition_heading eh JOIN heading h ON h.id = eh.heading_id
            WHERE eh.edition_id IN (\(Self.placeholders(ids.count))) GROUP BY h.id
            """,
            ids.map { .integer($0) }
        ) { (id: $0.integer(0) ?? 0, name: $0.text(1) ?? "", count: $0.integer(2) ?? 0) }
        // More than half the editions, so one oddly catalogued edition cannot steer it.
        for heading in headings where heading.count * 2 > ids.count && !Self.genericHeadings.contains(heading.name) {
            let members = try database.rows(
                "SELECT edition_id FROM edition_heading WHERE heading_id = ? LIMIT ?",
                [.integer(heading.id), .integer(limits.maximumHeadingEditions + 1)]
            ) { $0.integer(0) ?? 0 }
            guard members.count <= limits.maximumHeadingEditions else { continue }
            signals.append((heading.name, log(total / Double(members.count)), members))
        }
        for series in Set(work.editions.compactMap(\.series)) {
            let members = try matching(CatalogueQuery.phrase(series, in: "series"), limit: limits.seriesEditions.upperBound + 1)
                .filter { $0.series == series }
                .map(\.id)
            guard limits.seriesEditions.contains(members.count) else { continue }
            signals.append((series, 0.5 * log(total / Double(members.count)), members))
        }

        var scores: [Int: (score: Double, reason: String, best: Double)] = [:]
        for signal in signals {
            for id in signal.editions {
                var entry = scores[id] ?? (0, signal.reason, 0)
                entry.score += signal.weight
                if signal.weight > entry.best { entry.reason = signal.reason; entry.best = signal.weight }
                scores[id] = entry
            }
        }
        // Ties broken by edition, so the same book suggests the same books on every launch.
        let strongest = scores.sorted { ($0.value.score, $1.key) > ($1.value.score, $0.key) }.prefix(400).map(\.key)
        guard !strongest.isEmpty else { return [] }
        let first = work.editions[0]
        let candidates = try database.rows(
            "SELECT \(Self.columns) FROM edition e WHERE e.id IN (\(Self.placeholders(strongest.count)))",
            strongest.map { .integer($0) },
            map: Self.edition
        ).filter {
            !Self.sameAuthor($0.leadAuthor, first.leadAuthor)
                && $0.language == first.language
                && $0.fiction == first.fiction
                && CatalogueWork.key(for: $0) != work.id
                && !Self.sameTitle($0.originalTitle, work.title)
        }

        let ranked = CatalogueWork.grouped(candidates).compactMap { other -> (Suggestion, Double)? in
            guard let best = other.editions.compactMap({ scores[$0.id] }).max(by: { $0.score < $1.score }),
                  best.score >= limits.minimumScore
            else { return nil }
            return (Suggestion(work: other, reason: best.reason), best.score + 1.5 * log(Double(other.editions.count)))
        }
        guard ranked.count >= limits.minimumWorks else { return [] }
        return ranked.sorted { $0.1 > $1.1 }.prefix(limits.limit).map(\.0)
    }

    private var cachedEditionCount: Int?

    func editionCount() throws -> Int {
        if let cachedEditionCount { return cachedEditionCount }
        let count = try database.rows("SELECT COUNT(*) FROM edition") { $0.integer(0) ?? 0 }.first ?? 0
        cachedEditionCount = count
        return count
    }

    private static func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ",")
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
