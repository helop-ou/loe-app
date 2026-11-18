import Foundation

/// Every edition of one book: the same title by the same authors.
nonisolated struct CatalogueWork: Identifiable, Hashable, Sendable {
    let id: String
    /// Newest first.
    let editions: [CatalogueEdition]

    var title: String { editions[0].title }
    var authors: String? { editions[0].authors }
    var language: String? { editions[0].language }

    static func key(for edition: CatalogueEdition) -> String {
        CatalogueQuery.folded(edition.title) + "|" + CatalogueQuery.folded(edition.authors ?? "")
    }

    /// Groups editions into works, the most often published first.
    static func grouped(_ editions: [CatalogueEdition]) -> [CatalogueWork] {
        ranked(editions.map { ($0, 0) }, query: "")
    }
    var firstYear: Int? { editions.compactMap(\.year).min() }
    var latestYear: Int? { editions.compactMap(\.year).max() }

    /// Groups search hits into works and ranks them. A title the reader typed exactly
    /// comes first, then the best match, nudged up by how often the book was published.
    /// `score` is FTS5's bm25, where lower is better.
    static func ranked(_ hits: [(edition: CatalogueEdition, score: Double)], query: String) -> [CatalogueWork] {
        let typed = CatalogueQuery.folded(query)
        var order: [String] = []
        var groups: [String: [(edition: CatalogueEdition, score: Double)]] = [:]
        for hit in hits {
            let key = key(for: hit.edition)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(hit)
        }
        let ranked = order.map { key -> (work: CatalogueWork, exact: Bool, score: Double) in
            let group = groups[key]!
            let editions = group.map(\.edition).sorted { ($0.year ?? 0) > ($1.year ?? 0) }
            let best = group.map(\.score).min()!
            let exact = CatalogueQuery.folded(editions[0].title) == typed
            return (CatalogueWork(id: key, editions: editions), exact, best - 2 * log(Double(editions.count)))
        }
        return ranked
            .sorted { $0.exact != $1.exact ? $0.exact : $0.score < $1.score }
            .map(\.work)
    }
}
