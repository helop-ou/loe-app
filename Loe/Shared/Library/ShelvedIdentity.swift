import Foundation

/// How a book on a shelf is recognised when it is met again, in Search, on its own
/// page or among suggestions. Titles and authors get corrected, in the catalogue
/// and on Open Library, so the book's record counts before its words.
nonisolated struct ShelvedIdentity: Hashable, Sendable {
    /// How surely a shelved book is the one asked about. The surest wins.
    enum Match: Comparable, Sendable {
        /// The other source's copy of the same book. See `SameBook`.
        case sameBook
        /// The same title and authors.
        case workKey
        /// The same catalogue record or Open Library work.
        case record
    }

    let workKey: String
    var source = ShelvedBook.Source.catalogue
    /// The catalogue edition that was shelved, or empty.
    var erbID = ""
    var openLibraryKey: String?
    let title: String
    var subtitle: String?
    let leadAuthor: String?

    func match(_ work: CatalogueWork) -> Match? {
        if !erbID.isEmpty, work.editions.contains(where: { $0.erbID == erbID }) { return .record }
        if let openLibraryKey, work.editions.contains(where: { $0.openLibrary?.workKey == openLibraryKey }) { return .record }
        if workKey == work.id { return .workKey }
        let asked = work.editions[0]
        let other: ShelvedBook.Source? = asked.openLibrary != nil ? .catalogue : asked.erbID.isEmpty ? nil : .openLibrary
        guard source == other else { return nil }
        let written = SameBook.keys(title: title, subtitle: subtitle, leadAuthor: leadAuthor)
        let wanted = SameBook.keys(title: asked.title, subtitle: asked.subtitle, leadAuthor: asked.leadAuthor)
        return written.isDisjoint(with: wanted) ? nil : .sameBook
    }
}
