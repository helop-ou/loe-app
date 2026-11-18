import Foundation

/// One published edition of a book, as the National Bibliography records it.
nonisolated struct CatalogueEdition: Identifiable, Hashable, Sendable {
    let id: Int
    let erbID: String
    let title: String
    let subtitle: String?
    let authors: String?
    let year: Int?
    let publisher: String?
    let originalTitle: String?
    let series: String?
    let seriesNumber: String?
    let fiction: Bool
}
