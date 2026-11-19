import Foundation

/// A book Loe suggests, and why.
nonisolated struct ReadNextSuggestion: Identifiable, Hashable, Sendable {
    /// A book on the reader's shelves that a suggestion comes from.
    struct Book: Hashable, Sendable {
        let title: String
        let language: String?
    }

    enum Reason: Hashable, Sendable {
        case nextInSeries(after: Book)
        case sameAuthor(as: Book)
        /// The favourites it shares subject headings, genres or a series with.
        case similar(to: [Book])
        /// A genre the reader said they like.
        case taste(Genre)
    }

    let work: CatalogueWork
    let reason: Reason

    var id: String { work.id }
}

/// What Loe suggests reading next, worked out on the phone from the reader's own
/// shelves and the catalogue. See docs/library.md, "Read next".
nonisolated enum ReadNext {
    /// A shelved book, copied off the main actor.
    struct Source: Hashable, Sendable {
        let work: CatalogueWork
        let shelf: Shelf
        let rating: Int?

        /// Four or five stars.
        var isFavourite: Bool { (rating ?? 0) >= 4 }

        /// A series the reader is reading or has finished a book of, and did not dislike.
        var continuesSeries: Bool { (shelf == .reading || shelf == .read) && (rating ?? 3) >= 3 }
    }

    /// A shelved book, enough to tell whether a suggestion is already on a shelf.
    struct Shelved: Hashable, Sendable {
        let workKey: String
        let title: String
        let leadAuthor: String?
    }

    struct Limits: Sendable {
        /// The favourites and series looked into, most recent first.
        var favourites = 8
        var series = 8
        var perAuthor = 3
        var perTaste = 4
        var total = 24
        var similarity = Catalogue.SimilarityLimits.standard

        static let standard = Limits()
    }

    /// The books suggestions start from: favourites, then the series being read, the
    /// most recently changed first.
    @MainActor
    static func sources(from books: [ShelvedBook]) -> [Source] {
        books
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { Source(work: $0.work, shelf: $0.shelf, rating: $0.rating) }
            .filter { $0.isFavourite || $0.continuesSeries }
    }

    @MainActor
    static func shelved(_ books: [ShelvedBook]) -> [Shelved] {
        books.map { Shelved(workKey: $0.workKey, title: $0.title, leadAuthor: $0.work.editions[0].leadAuthor) }
    }

    static func suggestions(
        from sources: [Source],
        tastes: [Genre] = [],
        excluding shelved: [Shelved],
        in catalogue: Catalogue,
        limits: Limits = .standard
    ) async throws -> [ReadNextSuggestion] {
        var series: [ReadNextSuggestion] = []
        var seriesFound: [Catalogue.SeriesNext] = []
        var byAuthor: [[(work: CatalogueWork, from: ReadNextSuggestion.Book)]] = []
        var similar: [[(work: CatalogueWork, from: ReadNextSuggestion.Book)]] = []
        var languages: [String] = []

        let favourites = sources.filter(\.isFavourite).prefix(limits.favourites)
        let continuing = sources.filter { $0.continuesSeries && !$0.isFavourite }.prefix(limits.series)
        for source in favourites {
            try Task.checkCancellation()
            guard let details = try? await catalogue.details(for: source.work, similarity: limits.similarity) else { continue }
            let work = CatalogueWork(id: source.work.id, editions: details.editions.isEmpty ? source.work.editions : details.editions)
            let book = ReadNextSuggestion.Book(title: work.title, language: work.language)
            languages += work.language.map { [$0] } ?? []
            if source.continuesSeries, let next = try? await catalogue.nextInSeries(after: work) {
                series.append(ReadNextSuggestion(work: next.work, reason: .nextInSeries(after: book)))
                seriesFound.append(next)
            }
            byAuthor.append(details.sameAuthor.map { ($0, book) })
            similar.append(details.similar.map { ($0.work, book) })
        }
        for source in continuing {
            try Task.checkCancellation()
            guard let editions = try? await catalogue.editions(of: source.work) else { continue }
            let work = CatalogueWork(id: source.work.id, editions: editions)
            languages += work.language.map { [$0] } ?? []
            if let next = try? await catalogue.nextInSeries(after: work) {
                let book = ReadNextSuggestion.Book(title: work.title, language: work.language)
                series.append(ReadNextSuggestion(work: next.work, reason: .nextInSeries(after: book)))
                seriesFound.append(next)
            }
        }
        // A series is suggested from its next book, never from further on.
        let fromTheStart = { (work: CatalogueWork) in
            !seriesFound.contains { $0.contains(work) } && (Catalogue.part(of: work.title)?.number ?? 1) == 1
        }
        // Tastes suggest in the language the reader reads most, Estonian until Loe knows.
        let language = Dictionary(grouping: languages, by: { $0 }).max { $0.value.count < $1.value.count }?.key ?? "est"
        var byTaste: [[(work: CatalogueWork, genre: Genre)]] = []
        for genre in tastes {
            try Task.checkCancellation()
            guard let works = try? await catalogue.works(withHeadings: genre.headings, language: language, limit: 50) else { continue }
            let fresh = works.filter { fromTheStart($0) && !isOnShelf($0, shelved) }
            byTaste.append(fresh.prefix(limits.perTaste).map { ($0, genre) })
        }
        return merged(
            series: series,
            byAuthor: byAuthor.map { Array($0.filter { fromTheStart($0.work) }.prefix(limits.perAuthor)) },
            similar: similar.map { $0.filter { fromTheStart($0.work) } },
            byTaste: byTaste,
            excluding: shelved,
            limit: limits.total
        )
    }

    /// One list from the four kinds: the next books in series first, then books by
    /// favourite authors, similar books and books for the reader's tastes in turn. A
    /// book is suggested once, for its first reason. A book similar to several
    /// favourites comes before one similar to a single favourite. `byAuthor` and
    /// `similar` hold one list per favourite, `byTaste` one per genre.
    static func merged(
        series: [ReadNextSuggestion],
        byAuthor: [[(work: CatalogueWork, from: ReadNextSuggestion.Book)]],
        similar: [[(work: CatalogueWork, from: ReadNextSuggestion.Book)]],
        byTaste: [[(work: CatalogueWork, genre: Genre)]] = [],
        excluding shelved: [Shelved],
        limit: Int
    ) -> [ReadNextSuggestion] {
        let authorQueue = interleaved(byAuthor).map { ReadNextSuggestion(work: $0.work, reason: .sameAuthor(as: $0.from)) }
        let tasteQueue = interleaved(byTaste).map { ReadNextSuggestion(work: $0.work, reason: .taste($0.genre)) }

        // The favourites each book is like, in the order of the favourites.
        var favourites: [String: [ReadNextSuggestion.Book]] = [:]
        var works: [String: CatalogueWork] = [:]
        for (work, book) in similar.joined() {
            works[work.id] = works[work.id] ?? work
            if !(favourites[work.id] ?? []).contains(book) { favourites[work.id, default: []].append(book) }
        }
        var order: [String] = []
        for (work, _) in interleaved(similar) where !order.contains(work.id) {
            order.append(work.id)
        }
        let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        let similarQueue = order
            .sorted { (favourites[$0]!.count, -position[$0]!) > (favourites[$1]!.count, -position[$1]!) }
            .map { ReadNextSuggestion(work: works[$0]!, reason: .similar(to: favourites[$0]!)) }

        var result: [ReadNextSuggestion] = []
        // Suggested books count as shelved, so another edition of one is not suggested again.
        var taken = shelved
        func take(_ suggestion: ReadNextSuggestion) {
            guard result.count < limit, !isOnShelf(suggestion.work, taken) else { return }
            result.append(suggestion)
            taken.append(Shelved(workKey: suggestion.id, title: suggestion.work.title, leadAuthor: suggestion.work.editions[0].leadAuthor))
        }
        series.forEach(take)
        for index in 0..<max(authorQueue.count, similarQueue.count, tasteQueue.count) {
            if index < authorQueue.count { take(authorQueue[index]) }
            if index < similarQueue.count { take(similarQueue[index]) }
            if index < tasteQueue.count { take(tasteQueue[index]) }
        }
        return result
    }

    /// Whether the reader already has this book, from any edition. A shelved title
    /// with a part or year after it, „Harry Potter ja saladuste kamber. 2. aasta“, is
    /// the same book as one without, by the same author.
    static func isOnShelf(_ work: CatalogueWork, _ shelved: [Shelved]) -> Bool {
        let author = work.editions[0].leadAuthor.map(CatalogueQuery.folded)
        return shelved.contains { book in
            if book.workKey == work.id { return true }
            guard book.leadAuthor.map(CatalogueQuery.folded) == author else { return false }
            return CatalogueQuery.folded(beforeFirstStop(book.title)) == CatalogueQuery.folded(work.title)
                || CatalogueQuery.folded(beforeFirstStop(work.title)) == CatalogueQuery.folded(book.title)
        }
    }

    private static func beforeFirstStop(_ title: String) -> String {
        title.range(of: ". ").map { String(title[..<$0.lowerBound]) } ?? title
    }

    /// The first of each list, then the second of each, and so on.
    private static func interleaved<Element>(_ lists: [[Element]]) -> [Element] {
        let longest = lists.map(\.count).max() ?? 0
        return (0..<longest).flatMap { index in lists.compactMap { index < $0.count ? $0[index] : nil } }
    }
}
