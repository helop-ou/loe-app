import SwiftUI

struct SearchResultRow: View {
    let work: CatalogueWork
    /// The reader's own photo, for a book that is on a shelf.
    var photo: Data?

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ListedCover(work: work, photo: photo, width: 56)
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

    private var details: String {
        let count = work.editions.count
        let editions = locale.localized("\(count) editions")
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
