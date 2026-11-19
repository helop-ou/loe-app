import Foundation

/// One published edition of a book, as the National Bibliography records it, or
/// a book from abroad as Open Library does, with no catalogue record.
nonisolated struct CatalogueEdition: Identifiable, Hashable, Sendable {
    let id: Int
    let erbID: String
    let title: String
    var subtitle: String? = nil
    var authors: String? = nil
    var translators: String? = nil
    var year: Int? = nil
    var publisher: String? = nil
    var place: String? = nil
    var language: String? = nil
    var originalTitle: String? = nil
    var originalLanguage: String? = nil
    var editionStatement: String? = nil
    var series: String? = nil
    var seriesNumber: String? = nil
    var pages: Int? = nil
    var fiction: Bool = false
    /// Set for a book from Open Library, whose `erbID` is empty.
    var openLibrary: OpenLibraryRecord? = nil

    /// The first author, which is how works by one person are found.
    var leadAuthor: String? {
        authors?.components(separatedBy: "; ").first
    }
}
