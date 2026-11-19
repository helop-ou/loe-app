import Foundation
import SwiftData

/// A book on one of the reader's shelves. It keeps its own title and authors, so
/// the shelves read the same with or without the catalogue, and through catalogue
/// updates. Every property is optional or has a default, as CloudKit sync requires.
@Model
final class ShelvedBook {
    /// `CatalogueWork.id` of the book, which finds every edition of it.
    var workKey: String = ""
    /// The edition the reader shelved.
    var erbID: String = ""
    var title: String = ""
    var authors: String?
    /// Stored by name so queries can filter on it. Read `shelf` instead.
    var shelfName: String = Shelf.wantToRead.rawValue
    /// One to five stars, or none.
    var rating: Int?
    var currentPage: Int?
    var pageCount: Int?
    var addedAt: Date = Date.now
    var startedAt: Date?
    var finishedAt: Date?
    var updatedAt: Date = Date.now
    /// The reader's own photo of the cover, small enough to sync.
    @Attribute(.externalStorage) var coverPhoto: Data?
    /// The cover's colour, read once when the photo was added. See `LoeTone.Sample`.
    var coverHue: Double?
    var coverSaturation: Double?
    /// Where the book came from, stored by name. Read `source` instead.
    var sourceName: String?
    /// Year and language, kept for a book the catalogue doesn't have.
    var year: Int?
    var language: String?

    /// A book from the catalogue, or one the reader entered because the catalogue
    /// doesn't have it.
    enum Source: String {
        case catalogue
        case hand
    }

    init(edition: CatalogueEdition, workKey: String, shelf: Shelf, now: Date = .now) {
        self.workKey = workKey
        erbID = edition.erbID
        title = edition.title
        authors = edition.authors
        pageCount = edition.pages
        addedAt = now
        updatedAt = now
        move(to: shelf, now: now)
    }

    /// A book the reader entered by hand. It has its own key, so it never merges
    /// with a catalogue book that has the same title.
    init(entered: EnteredBook, shelf: Shelf, now: Date = .now) {
        workKey = "hand:" + UUID().uuidString
        sourceName = Source.hand.rawValue
        addedAt = now
        update(from: entered, now: now)
        move(to: shelf, now: now)
    }

    var shelf: Shelf {
        Shelf(rawValue: shelfName) ?? .wantToRead
    }

    /// Records from before books could be entered by hand have no source and came
    /// from the catalogue.
    var source: Source {
        sourceName.flatMap(Source.init(rawValue:)) ?? .catalogue
    }

    /// What the reader entered, as it stands now.
    var entered: EnteredBook {
        EnteredBook(title: title, authors: authors.map { $0.replacingOccurrences(of: "; ", with: ", ") } ?? "",
                    pages: pageCount, year: year, language: language)
    }

    /// Changes what the reader entered for a book the catalogue doesn't have.
    func update(from entered: EnteredBook, now: Date = .now) {
        title = entered.cleanTitle
        authors = entered.cleanAuthors
        pageCount = entered.cleanPages
        if shelf == .read, let pageCount {
            currentPage = pageCount
        } else if let currentPage, let pageCount {
            self.currentPage = min(currentPage, pageCount)
        }
        year = entered.cleanYear
        language = entered.language
        updatedAt = now
    }

    /// Starting a book records when, once. Finishing one records when and puts the
    /// bookmark on the last page.
    func move(to shelf: Shelf, now: Date = .now) {
        shelfName = shelf.rawValue
        switch shelf {
        case .reading:
            startedAt = startedAt ?? now
        case .read:
            finishedAt = now
            if let pageCount { currentPage = pageCount }
        case .wantToRead, .setAside, .didNotFinish:
            break
        }
        updatedAt = now
    }

    func rate(_ stars: Int?, now: Date = .now) {
        rating = stars.map { min(max($0, 1), 5) }
        updatedAt = now
    }

    func setPage(_ page: Int, of pages: Int?, now: Date = .now) {
        pageCount = pages.flatMap { $0 > 0 ? $0 : nil }
        currentPage = min(max(page, 0), pageCount ?? .max)
        updatedAt = now
    }

    func setCover(_ cover: CoverPhoto?, now: Date = .now) {
        coverPhoto = cover?.jpeg
        coverHue = cover?.sample.hue
        coverSaturation = cover?.sample.saturation
        updatedAt = now
    }

    var coverSample: LoeTone.Sample? {
        guard let coverHue, let coverSaturation else { return nil }
        return LoeTone.Sample(hue: coverHue, saturation: coverSaturation, weight: Double(rating ?? 3))
    }

    /// How far through the book the reader is, when both numbers are known.
    var progress: Double? {
        guard let currentPage, let pageCount, pageCount > 0 else { return nil }
        return Double(currentPage) / Double(pageCount)
    }

    /// Enough of the book to open its page. The page finds the rest in the catalogue.
    var work: CatalogueWork {
        CatalogueWork(id: workKey, editions: [
            CatalogueEdition(id: 0, erbID: erbID, title: title, authors: authors, year: year, language: language, pages: pageCount),
        ])
    }
}

extension ShelvedBook {
    /// Puts a book on a shelf, or moves it there if it is already on one. A book is
    /// on one shelf at a time, whichever edition the reader came from.
    @discardableResult
    static func shelve(
        _ work: CatalogueWork,
        edition: CatalogueEdition,
        on shelf: Shelf,
        in context: ModelContext,
        now: Date = .now
    ) throws -> ShelvedBook {
        if let existing = try find(work.id, in: context) {
            existing.move(to: shelf, now: now)
            return existing
        }
        let book = ShelvedBook(edition: edition, workKey: work.id, shelf: shelf, now: now)
        context.insert(book)
        return book
    }

    /// Puts a book the reader entered by hand on a shelf.
    @discardableResult
    static func add(_ entered: EnteredBook, on shelf: Shelf, in context: ModelContext, now: Date = .now) -> ShelvedBook {
        let book = ShelvedBook(entered: entered, shelf: shelf, now: now)
        context.insert(book)
        return book
    }

    static func find(_ workKey: String, in context: ModelContext) throws -> ShelvedBook? {
        var descriptor = FetchDescriptor<ShelvedBook>(predicate: #Predicate { $0.workKey == workKey })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
