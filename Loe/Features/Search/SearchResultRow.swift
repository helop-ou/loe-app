import SwiftUI

struct SearchResultRow: View {
    let work: CatalogueWork

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BookCover(title: work.title, art: Self.art(for: work), width: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(work.title)
                    .loeHeading(.inline)
                    .foregroundStyle(.loeInk)
                if let authors = work.authors {
                    Text(authors)
                        .foregroundStyle(.loeSecondary)
                }
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(.loeSecondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    /// Only by cover id, which Open Library does not limit. Lookups by ISBN, for a
    /// catalogue book or one from Open Library with no cover id, are limited, so
    /// they wait for the book's own page and the shelves.
    static func art(for work: CatalogueWork) -> CoverArt? {
        work.editions[0].openLibrary?.coverID.map(CoverArt.id)
    }

    private var details: String {
        let count = work.editions.count
        let editions = String(localized: "\(count) editions")
        switch (work.firstYear, work.latestYear) {
        case let (first?, latest?) where first != latest:
            return "\(first)–\(latest) · \(editions)"
        case let (year?, _):
            return count > 1 ? "\(year) · \(editions)" : String(year)
        default:
            return editions
        }
    }
}
