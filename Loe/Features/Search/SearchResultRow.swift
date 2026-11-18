import SwiftUI

struct SearchResultRow: View {
    let work: CatalogueWork

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BlankCover(title: work.title, width: 56)
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
