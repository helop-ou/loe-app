import Foundation

/// Where a book from Open Library lives there, kept with it so its page and its
/// cover can be found again.
nonisolated struct OpenLibraryRecord: Hashable, Sendable {
    /// Such as "/works/OL29226517W".
    let workKey: String
    var isbn: String?
    var coverID: Int?

    var url: URL? { URL(string: "https://openlibrary.org" + workKey) }
}

/// A book found on Open Library, for books the catalogue doesn't have, such as
/// English books published abroad. See docs/catalogue.md, "Books from abroad".
nonisolated struct OpenLibraryBook: Hashable, Sendable, Identifiable {
    let record: OpenLibraryRecord
    let title: String
    let authors: [String]
    var year: Int?
    var pages: Int?
    var language: String?

    var id: String { record.workKey }

    /// The book as the rest of Loe opens and shelves it: a work with one edition and
    /// no catalogue record. Its key is the catalogue's, so an English book the
    /// catalogue also has stays one book on the shelves.
    var work: CatalogueWork {
        let edition = CatalogueEdition(
            id: 0, erbID: "", title: title,
            authors: authors.isEmpty ? nil : authors.joined(separator: "; "),
            year: year, language: language, pages: pages, openLibrary: record
        )
        return CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
    }

    /// Every way this book can be written. See `SameBook`.
    var sameBookKeys: Set<String> {
        SameBook.keys(title: title, leadAuthor: authors.first)
    }

    /// The books in an answer, each once. Open Library often has one book as several
    /// works, so a book already seen is left out. A book filed under another book's
    /// work gives way to the work that is its own.
    static func books(in response: OpenLibrarySearchResponse) -> [OpenLibraryBook] {
        var found: [(book: OpenLibraryBook, misfiled: Bool)] = []
        for doc in response.docs ?? [] {
            guard let next = read(doc) else { continue }
            let keys = next.book.sameBookKeys
            if let index = found.firstIndex(where: { !$0.book.sameBookKeys.isDisjoint(with: keys) }) {
                if found[index].misfiled && !next.misfiled { found[index] = next }
            } else {
                found.append(next)
            }
        }
        return found.map(\.book)
    }

    /// Books the catalogue's results don't already show.
    static func unseen(_ books: [OpenLibraryBook], besides works: [CatalogueWork]) -> [OpenLibraryBook] {
        let shown = works.reduce(into: Set<String>()) { keys, work in
            let edition = work.editions[0]
            keys.formUnion(SameBook.keys(title: work.title, subtitle: edition.subtitle, leadAuthor: edition.leadAuthor))
        }
        return books.filter { shown.isDisjoint(with: $0.sameBookKeys) }
    }

    private static func read(_ doc: OpenLibrarySearchResponse.Doc) -> (book: OpenLibraryBook, misfiled: Bool)? {
        guard let key = doc.key, key.hasPrefix("/works/"), let workTitle = doc.title?.trimmed, !workTitle.isEmpty else { return nil }
        let edition = doc.editions?.docs?.first
        let work = (title: workTitle, subtitle: doc.subtitle?.trimmed)
        let shown = edition.map { (title: $0.title?.trimmed ?? "", subtitle: $0.subtitle?.trimmed) }
        let isbn = edition?.isbn?.lazy.compactMap { CatalogueQuery.isbn13($0) }.first
        let languages = edition?.language ?? []
        let book = OpenLibraryBook(
            // The work's own cover can be another book's, so the edition shown comes first.
            record: OpenLibraryRecord(workKey: key, isbn: isbn, coverID: edition?.coverID ?? doc.coverID),
            title: displayTitle(work: work, edition: shown),
            authors: (doc.authors ?? []).map(\.trimmed).filter { !$0.isEmpty },
            year: doc.firstPublishYear,
            pages: doc.pages.flatMap { $0 > 0 ? $0 : nil },
            language: languages.contains("eng") ? "eng" : languages.first
        )
        return (book, isFiledUnderAnother(work: work, edition: shown))
    }

    /// The work's title, which is the book's own, unless the English edition shows
    /// it better. A work with no subtitle takes its edition's ("Halo" and "The Fall
    /// of Reach") when it is short enough to be one, and so does an edition filed
    /// under another book's work. A translated book is filed under its original, so
    /// when the two titles share nothing the edition's English one is shown.
    static func displayTitle(work: (title: String, subtitle: String?), edition: (title: String, subtitle: String?)?) -> String {
        let workTitle = joined(work.title, work.subtitle)
        guard let edition, !edition.title.isEmpty else { return workTitle }
        let foldedWork = CatalogueQuery.folded(work.title)
        let foldedEdition = CatalogueQuery.folded(edition.title)
        if foldedWork == foldedEdition {
            let takesEditions = work.subtitle == nil || isFiledUnderAnother(work: work, edition: edition)
            return takesEditions ? joined(work.title, subtitle(of: edition)) : workTitle
        }
        if foldedEdition.contains(foldedWork) || foldedWork.contains(foldedEdition) {
            return workTitle
        }
        return joined(edition.title, edition.subtitle)
    }

    /// Whether the edition found is another book than the work it sits under: the
    /// same title with another subtitle, as an edition of "Halo: The Fall of Reach"
    /// sits under "Halo: First Strike". The edition is the book that was found.
    static func isFiledUnderAnother(work: (title: String, subtitle: String?), edition: (title: String, subtitle: String?)?) -> Bool {
        guard let edition, let found = subtitle(of: edition), let own = work.subtitle, !own.isEmpty else { return false }
        return CatalogueQuery.folded(work.title) == CatalogueQuery.folded(edition.title)
            && CatalogueQuery.folded(own) != CatalogueQuery.folded(found)
    }

    /// A long subtitle on an edition is a publisher's blurb, not part of the title.
    private static func subtitle(of edition: (title: String, subtitle: String?)) -> String? {
        guard let subtitle = edition.subtitle, !subtitle.isEmpty, subtitle.split(separator: " ").count <= 7 else { return nil }
        return subtitle
    }

    private static func joined(_ title: String, _ subtitle: String?) -> String {
        guard let subtitle, !subtitle.isEmpty else { return title }
        return "\(title): \(subtitle)"
    }
}

/// What Open Library's search answers, read defensively: its schema "is not
/// guaranteed to be stable", so every field may be missing.
nonisolated struct OpenLibrarySearchResponse: Decodable, Sendable {
    var docs: [Doc]?

    struct Doc: Decodable, Sendable {
        var key: String?
        var title: String?
        var subtitle: String?
        var authors: [String]?
        var firstPublishYear: Int?
        var pages: Int?
        var coverID: Int?
        var editions: Editions?

        enum CodingKeys: String, CodingKey {
            case key, title, subtitle, editions
            case authors = "author_name"
            case firstPublishYear = "first_publish_year"
            case pages = "number_of_pages_median"
            case coverID = "cover_i"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            key = try? container.decode(String.self, forKey: .key)
            title = try? container.decode(String.self, forKey: .title)
            subtitle = try? container.decode(String.self, forKey: .subtitle)
            authors = try? container.decode([String].self, forKey: .authors)
            firstPublishYear = try? container.decode(Int.self, forKey: .firstPublishYear)
            pages = try? container.decode(Int.self, forKey: .pages)
            coverID = try? container.decode(Int.self, forKey: .coverID)
            editions = try? container.decode(Editions.self, forKey: .editions)
        }
    }

    struct Editions: Decodable, Sendable {
        var docs: [Edition]?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            docs = try? container.decode([Edition].self, forKey: .docs)
        }

        enum CodingKeys: String, CodingKey { case docs }
    }

    struct Edition: Decodable, Sendable {
        var title: String?
        var subtitle: String?
        var language: [String]?
        var isbn: [String]?
        var coverID: Int?

        enum CodingKeys: String, CodingKey {
            case title, subtitle, language, isbn
            case coverID = "cover_i"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try? container.decode(String.self, forKey: .title)
            subtitle = try? container.decode(String.self, forKey: .subtitle)
            language = try? container.decode([String].self, forKey: .language)
            isbn = try? container.decode([String].self, forKey: .isbn)
            coverID = try? container.decode(Int.self, forKey: .coverID)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // One malformed doc must not hide the others.
        docs = (try? container.decode([Lenient<Doc>].self, forKey: .docs))?.compactMap(\.value)
    }

    enum CodingKeys: String, CodingKey { case docs }
}

private nonisolated struct Lenient<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
}

private extension String {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
