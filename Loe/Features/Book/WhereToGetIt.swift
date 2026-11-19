import SwiftData
import SwiftUI

/// The reader's libraries and bookshops, in their order, or ESTER and two bookshops
/// when they have picked none. Each library says whether it has the book, asked of
/// ESTER as the page opens. See docs/library.md, "Availability".
struct WhereToGetIt: View {
    /// The work with all its editions, newest first.
    let work: CatalogueWork
    /// The edition the page shows.
    let edition: CatalogueEdition
    var checker = AvailabilityChecker.live

    @Query private var chosen: [ChosenPlace]
    @State private var copies: Copies = .checking

    enum Copies: Equatable {
        case checking
        case found([String: [LibraryCopy]])
        case failed
    }

    private struct Request: Equatable {
        let editions: [String]
        let asks: Bool
    }

    var body: some View {
        let places = ChosenPlace.places(chosen)
        let asksESTER = Self.asksESTER(places: places, editions: work.editions)
        let rows = rows(places)
        if !rows.isEmpty {
            WhereToGetItCard(rows: rows, namesESTER: asksESTER)
                .task(id: Request(editions: work.editions.map(\.erbID), asks: asksESTER)) {
                    guard asksESTER else { return }
                    copies = .checking
                    let found = await checker.copies(of: work.editions)
                    guard !Task.isCancelled else { return }
                    copies = found.map(Copies.found) ?? .failed
                }
        }
    }

    /// ESTER is asked only for a picked library and a book it has a record of. A
    /// book entered by hand has none.
    static func asksESTER(places: [Place], editions: [CatalogueEdition]) -> Bool {
        places.contains { $0.kind == .library } && editions.contains { BookLinks.ester($0.erbID) != nil }
    }

    private func rows(_ places: [Place]) -> [WhereToGetItCard.Row] {
        let query = BookLinks.query(for: work)
        let ester = BookLinks.ester(edition.erbID)
        guard !places.isEmpty else {
            return [
                ester.map { .init(id: "ester", name: "ESTER", detail: Text("See if your library has it"), url: $0) },
                BookLinks.rahvaRaamat(query).map { .init(id: Place.rahvaRaamat.id, name: Place.rahvaRaamat.name, detail: Text("Bookshop"), url: $0) },
                BookLinks.apollo(query).map { .init(id: Place.apollo.id, name: Place.apollo.name, detail: Text("Bookshop"), url: $0) },
            ].compactMap { $0 }
        }
        return places.compactMap { place in
            switch place.kind {
            case .library:
                ester.map { url in
                    WhereToGetItCard.Row(
                        id: place.id, name: place.name,
                        detail: place.group.map { Text(verbatim: $0) } ?? Text("Library"),
                        url: url, status: status(at: place)
                    )
                }
            case .shop:
                BookLinks.shop(place, query: query).map { .init(id: place.id, name: place.name, detail: Text("Bookshop"), url: $0) }
            }
        }
    }

    private func status(at place: Place) -> WhereToGetItCard.Status {
        switch copies {
        case .checking: .checking
        case .failed: .failed
        case .found(let copies):
            .known(LibraryAvailability.of(place, copies: copies, editions: work.editions, onScreen: edition.erbID))
        }
    }
}

/// The rows of "Where to get it", each a link, with a library's availability under it.
struct WhereToGetItCard: View {
    enum Status: Equatable {
        case checking
        case failed
        case known(LibraryAvailability)
    }

    struct Row: Identifiable {
        let id: String
        let name: String
        let detail: Text
        let url: URL
        var status: Status?
    }

    let rows: [Row]
    /// ESTER's statutes ask anything showing its data to name it.
    let namesESTER: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where to get it")
                .loeHeading(.section)
                .foregroundStyle(.loeInk)
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    LinkRow(row: row)
                    if row.id != rows.last?.id {
                        Divider().overlay(.loeHairline)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(.loeCard, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.loeHairline))
            Group {
                if namesESTER {
                    Text("Whether a library has the book comes from ESTER, the libraries' catalogue, which Loe asks about this book and nothing else. Links open in your browser.")
                } else {
                    Text("Opens in your browser. Choose your libraries and shops in Settings.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.loeSecondary)
        }
    }
}

private struct LinkRow: View {
    let row: WhereToGetItCard.Row

    var body: some View {
        Link(destination: row.url) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.loeInk)
                    row.detail
                        .font(.subheadline)
                        .foregroundStyle(.loeSecondary)
                    if let status = row.status {
                        StatusLine(status: status)
                            .padding(.top, 4)
                    }
                }
                // A link centres its lines when they wrap.
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.loeAccent)
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A library's availability: an icon and a few words.
private struct StatusLine: View {
    let status: WhereToGetItCard.Status

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Group {
                if status == .checking {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: symbol)
                        .foregroundStyle(isGood ? Color.loeAccent : Color.loeSecondary)
                }
            }
            .accessibilityHidden(true)
            text
                .foregroundStyle(isGood ? Color.loeInk : Color.loeSecondary)
        }
        .font(.subheadline.weight(isGood ? .semibold : .regular))
    }

    /// On a shelf, where a reader can take it today.
    private var isGood: Bool {
        switch status {
        case .known(.onShelf), .known(.otherEditionOnShelf): true
        default: false
        }
    }

    private var symbol: String {
        switch status {
        case .checking, .failed: "wifi.exclamationmark"
        case .known(let availability):
            switch availability {
            case .onShelf, .otherEditionOnShelf: "checkmark.circle.fill"
            case .inStorage: "shippingbox"
            case .onLoan: "clock"
            case .inTransit: "arrow.left.arrow.right"
            case .readThere: "book.closed"
            case .notHere: "minus.circle"
            }
        }
    }

    private var text: Text {
        switch status {
        case .checking: Text("Checking…")
        case .failed: Text("Couldn't check right now")
        case .known(let availability):
            switch availability {
            case .onShelf: Text("On the shelf")
            case .otherEditionOnShelf(let year?): Text("On the shelf: the \(String(year)) edition")
            case .otherEditionOnShelf(nil): Text("On the shelf: another edition")
            case .inStorage: Text("In storage, can be ordered")
            case .onLoan(let due?):
                Text("Due back \(Text(Calendar(identifier: .gregorian).date(from: due) ?? .now, format: .dateTime.day().month()))")
            case .onLoan(nil): Text("On loan, overdue")
            case .inTransit: Text("On its way between libraries")
            case .readThere: Text("Only to read in the library")
            case .notHere: Text("Not in this library")
            }
        }
    }
}
