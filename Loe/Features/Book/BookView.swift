import SwiftData
import SwiftUI

/// A book's own page: its cover and title, how it relates to its original or its
/// translations, its editions, and where to get it.
struct BookView: View {
    let work: CatalogueWork

    @Environment(CatalogueStore.self) private var catalogue
    @Environment(\.colorScheme) private var colorScheme
    @State private var details: Catalogue.Details?
    @Query private var shelved: [ShelvedBook]

    init(work: CatalogueWork) {
        self.work = work
        let key = work.id
        _shelved = Query(filter: #Predicate<ShelvedBook> { $0.workKey == key })
    }

    private var book: ShelvedBook? { shelved.first }

    /// The work with every edition once they have loaded. A page opened from a shelf
    /// starts with only the edition that was shelved.
    private var shown: CatalogueWork {
        guard let editions = details?.editions, !editions.isEmpty else { return work }
        return CatalogueWork(id: work.id, editions: editions)
    }

    private var newest: CatalogueEdition { shown.editions[0] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                BookHeader(work: shown, edition: newest, book: book)
                ShelfControls(work: shown, edition: newest, book: book)
                if newest.originalTitle != nil {
                    OriginalCard(edition: newest, original: details?.original)
                }
                if let details {
                    if !details.translations.isEmpty {
                        WorkRail(title: "Translations", works: details.translations) { work in
                            LanguageName.of(work.language).map { String(localized: "In \($0)") }
                        }
                    }
                    EditionsSection(editions: details.editions)
                    WhereToGetIt(work: shown, edition: newest)
                    if !details.sameAuthor.isEmpty {
                        WorkRail(title: "By the same author", works: details.sameAuthor) { work in
                            work.firstYear.map(String.init)
                        }
                    }
                    if !details.similar.isEmpty {
                        // The caption is what the book shares with this one: a subject
                        // heading, genre or series, as the library names it.
                        let reasons = Dictionary(details.similar.map { ($0.work.id, $0.reason) }, uniquingKeysWith: { first, _ in first })
                        WorkRail(title: "Similar books", works: details.similar.map(\.work)) { work in
                            reasons[work.id]
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background {
            // A book's own page takes a soft wash of its cover's colour.
            if let wash = book?.coverSample.flatMap({ CoverWash.color($0, dark: colorScheme == .dark, surface: .page) }) {
                LinearGradient(colors: [wash, .loeBackground], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55))
                    .ignoresSafeArea()
            } else {
                Color.loeBackground.ignoresSafeArea()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: work.id) {
            guard case .ready(let catalogue) = catalogue.state else { return }
            details = try? await catalogue.details(for: work)
        }
    }
}

private struct BookHeader: View {
    let work: CatalogueWork
    let edition: CatalogueEdition
    let book: ShelvedBook?

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            if let book {
                CoverPhotoMenu(book: book, title: work.title, width: 140)
            } else {
                BookCover(title: work.title, width: 140)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(work.title)
                    .loeHeading(.bookTitle)
                    .foregroundStyle(.loeInk)
                if let subtitle = edition.subtitle {
                    Text(subtitle)
                        .foregroundStyle(.loeSecondary)
                }
                if let authors = work.authors {
                    Text(authors.replacingOccurrences(of: "; ", with: ", "))
                        .font(.title3)
                        .foregroundStyle(.loeSecondary)
                        .padding(.top, 2)
                }
                if let translators = edition.translators {
                    Text("Translated by \(translators.replacingOccurrences(of: "; ", with: ", "))")
                        .font(.footnote)
                        .foregroundStyle(.loeSecondary)
                }
                if let years = Self.years(work) {
                    Text(years)
                        .font(.subheadline)
                        .foregroundStyle(.loeSecondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    static func years(_ work: CatalogueWork) -> String? {
        switch (work.firstYear, work.latestYear) {
        case let (first?, latest?) where first != latest: "\(first)–\(latest)"
        case let (year?, _): String(year)
        default: nil
        }
    }
}

/// For a translation: the language it came from, and the original when the
/// catalogue has it.
private struct OriginalCard: View {
    let edition: CatalogueEdition
    let original: CatalogueWork?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let language = LanguageName.of(edition.originalLanguage) {
                    Text("Translated from \(language)")
                } else {
                    Text("Translated")
                }
            }
            .foregroundStyle(.loeInk)
            if let original {
                NavigationLink(value: original) {
                    HStack(spacing: 14) {
                        BlankCover(title: original.title, width: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(original.title)
                                .loeHeading(.inline)
                                .foregroundStyle(.loeInk)
                            if let years = BookHeader.years(original) {
                                Text(years)
                                    .font(.subheadline)
                                    .foregroundStyle(.loeSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.loeSecondary)
                    }
                    .padding(12)
                    .background(.loeCard, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else if let title = edition.originalTitle {
                Text(title)
                    .loeHeading(.inline, italic: true)
                    .foregroundStyle(.loeInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.loeHairline.opacity(0.5), in: .rect(cornerRadius: 18))
    }
}

private struct EditionsSection: View {
    let editions: [CatalogueEdition]
    @State private var showsAll = false

    private static let shortList = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Editions")
                .loeHeading(.section)
                .foregroundStyle(.loeInk)
            VStack(alignment: .leading, spacing: 0) {
                let shown = showsAll ? editions : Array(editions.prefix(Self.shortList))
                ForEach(shown) { edition in
                    EditionRow(edition: edition)
                    if edition.id != shown.last?.id {
                        Divider().overlay(.loeHairline)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(.loeCard, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.loeHairline))
            if editions.count > Self.shortList && !showsAll {
                Button("Show all \(editions.count) editions") { showsAll = true }
                    .tint(.loeAccent)
            }
        }
    }
}

private struct EditionRow: View {
    let edition: CatalogueEdition

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(edition.year.map(String.init) ?? "–")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.loeInk)
                if let publisher = edition.publisher {
                    Text(publisher)
                        .foregroundStyle(.loeInk)
                }
            }
            let details = [edition.editionStatement, edition.pages.map { String(localized: "\($0) pages") }]
                .compactMap { $0 }
            if !details.isEmpty {
                Text(details.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.loeSecondary)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// The reader's libraries and bookshops, in their order, or ESTER and two bookshops
/// when they have not picked any.
private struct WhereToGetIt: View {
    let work: CatalogueWork
    let edition: CatalogueEdition

    @Query private var chosen: [ChosenPlace]

    private struct Row: Identifiable {
        let id: String
        let name: String
        let detail: Text
        let url: URL
    }

    private var rows: [Row] {
        let query = BookLinks.query(for: work)
        let ester = BookLinks.ester(edition.erbID)
        let places = ChosenPlace.places(chosen)
        guard !places.isEmpty else {
            return [
                ester.map { Row(id: "ester", name: "ESTER", detail: Text("See if your library has it"), url: $0) },
                BookLinks.rahvaRaamat(query).map { Row(id: Place.rahvaRaamat.id, name: Place.rahvaRaamat.name, detail: Text("Bookshop"), url: $0) },
                BookLinks.apollo(query).map { Row(id: Place.apollo.id, name: Place.apollo.name, detail: Text("Bookshop"), url: $0) },
            ].compactMap { $0 }
        }
        return places.compactMap { place in
            switch place.kind {
            case .library:
                ester.map { Row(id: place.id, name: place.name, detail: place.group.map { Text(verbatim: $0) } ?? Text("Library"), url: $0) }
            case .shop:
                BookLinks.shop(place, query: query).map { Row(id: place.id, name: place.name, detail: Text("Bookshop"), url: $0) }
            }
        }
    }

    var body: some View {
        let rows = rows
        VStack(alignment: .leading, spacing: 12) {
            Text("Where to get it")
                .loeHeading(.section)
                .foregroundStyle(.loeInk)
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    LinkRow(name: row.name, detail: row.detail, url: row.url)
                    if row.id != rows.last?.id {
                        Divider().overlay(.loeHairline)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(.loeCard, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.loeHairline))
            Text("Opens in your browser. Choose your libraries and shops in Settings.")
                .font(.footnote)
                .foregroundStyle(.loeSecondary)
        }
    }
}

private struct LinkRow: View {
    let name: String
    let detail: Text
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.loeInk)
                    detail
                        .font(.subheadline)
                        .foregroundStyle(.loeSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.loeAccent)
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
    }
}

/// A row of books to move on to, each opening its own page.
private struct WorkRail: View {
    let title: LocalizedStringKey
    let works: [CatalogueWork]
    let caption: (CatalogueWork) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .loeHeading(.section)
                .foregroundStyle(.loeInk)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(works) { work in
                        NavigationLink(value: work) {
                            VStack(alignment: .leading, spacing: 6) {
                                BlankCover(title: work.title, width: 96)
                                Text(work.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.loeInk)
                                    .lineLimit(2)
                                if let caption = caption(work) {
                                    Text(caption)
                                        .font(.footnote)
                                        .foregroundStyle(.loeSecondary)
                                }
                            }
                            .frame(width: 96, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}
