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
    typealias Shelved = ShelvedIdentity

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
        books.map(\.identity)
    }

    static func suggestions(
        from sources: [Source],
        tastes: [Genre] = [],
        excluding shelved: [Shelved],
        in catalogue: Catalogue,
        limits: Limits = .standard
    ) async throws -> [ReadNextSuggestion] {
        var found: [Leads] = []
        var languages: [String] = []
        /// The translations that stood in for books from abroad. The reader has
        /// read the book, so its translation is not suggested to them.
        var standIns: [Shelved] = []

        let favourites = sources.filter(\.isFavourite).prefix(limits.favourites)
        let continuing = sources.filter { $0.continuesSeries && !$0.isFavourite }.prefix(limits.series)
        for source in favourites {
            try Task.checkCancellation()
            guard let details = try? await catalogue.details(for: source.work, similarity: limits.similarity) else { continue }
            let work = CatalogueWork(id: source.work.id, editions: details.editions.isEmpty ? source.work.editions : details.editions)
            var leads = Leads(from: ReadNextSuggestion.Book(title: work.title, language: work.language))
            languages += work.language.map { [$0] } ?? []
            leads.byAuthor = details.sameAuthor
            leads.similar = details.similar.map(\.work)
            if details.sameAuthorIsInEstonian { leads.language = Catalogue.estonian }
            // A book from abroad has no headings or series in the catalogue. Its
            // translation has, and stands in for it.
            var followed = work
            if let standIn = standIn(for: source.work, among: details.translations) {
                standIns.append(Shelved(workKey: standIn.id, title: standIn.title, leadAuthor: standIn.editions[0].leadAuthor))
                leads.language = standIn.language
                leads.similar = (try? await catalogue.similar(to: standIn, limits: limits.similarity))?.map(\.work) ?? []
                followed = standIn
            }
            if source.continuesSeries { leads.series = try? await catalogue.nextInSeries(after: followed) }
            found.append(leads)
        }
        for source in continuing {
            try Task.checkCancellation()
            guard let editions = try? await catalogue.editions(of: source.work) else { continue }
            let work = CatalogueWork(id: source.work.id, editions: editions)
            languages += work.language.map { [$0] } ?? []
            var leads = Leads(from: ReadNextSuggestion.Book(title: work.title, language: work.language))
            var followed = work
            if source.work.editions[0].openLibrary != nil,
               let translations = try? await catalogue.details(for: source.work, similarity: limits.similarity).translations,
               let standIn = standIn(for: source.work, among: translations) {
                standIns.append(Shelved(workKey: standIn.id, title: standIn.title, leadAuthor: standIn.editions[0].leadAuthor))
                leads.language = standIn.language
                followed = standIn
            }
            leads.series = try? await catalogue.nextInSeries(after: followed)
            found.append(leads)
        }
        // Tastes suggest in the language the reader reads most, Estonian until Loe knows.
        let language = Dictionary(grouping: languages, by: { $0 }).max { $0.value.count < $1.value.count }?.key ?? Catalogue.estonian
        // What a book from abroad brings is in Estonian: its author's books and
        // whatever its translation leads to. A reader who reads mostly in another
        // language is not handed them.
        let kept = found.filter { $0.language == nil || $0.language == language }
        let seriesFound = kept.compactMap(\.series)
        let series = kept.compactMap { leads in leads.series.map { ReadNextSuggestion(work: $0.work, reason: .nextInSeries(after: leads.from)) } }
        let byAuthor = kept.map { leads in leads.byAuthor.map { (work: $0, from: leads.from) } }
        let similar = kept.map { leads in leads.similar.map { (work: $0, from: leads.from) } }
        let shelved = shelved + standIns
        // A series is suggested from its next book, never from further on.
        let fromTheStart = { (work: CatalogueWork) in
            !seriesFound.contains { $0.contains(work) } && (Catalogue.part(of: work.title)?.number ?? 1) == 1
        }
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

    /// What one of the reader's books leads to, before the kinds are put together.
    private struct Leads {
        /// The book the reader shelved, which a suggestion's reason names.
        let from: ReadNextSuggestion.Book
        var series: Catalogue.SeriesNext?
        var byAuthor: [CatalogueWork] = []
        var similar: [CatalogueWork] = []
        /// The language these are in, when it is not the book's own.
        var language: String?

        init(from book: ReadNextSuggestion.Book) {
            from = book
        }
    }

    /// The catalogue's Estonian translation of a book from abroad, which stands in
    /// for it: the catalogue knows the translation's headings and series, and
    /// nothing of a book it does not hold. Nil for a catalogue book.
    private static func standIn(for work: CatalogueWork, among translations: [CatalogueWork]) -> CatalogueWork? {
        guard work.editions[0].openLibrary != nil else { return nil }
        return translations.first { $0.language == Catalogue.estonian }
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
            if book.match(work) != nil { return true }
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
