import SwiftData
import SwiftUI

/// A book's own page: its cover and title, how it relates to its original or its
/// translations, its editions, and where to get it.
struct BookView: View {
    let work: CatalogueWork

    @Environment(CatalogueStore.self) private var catalogue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var details: Catalogue.Details?
    @State private var editing = false
    @State private var enteredByHand = false
    @State private var openLibraryCover: Covers.Loaded?
    @Query private var shelves: [ShelvedBook]

    /// The reader's copy of this book, found by its record before its title, which
    /// may have been corrected since it was shelved. See `ShelvedIdentity`.
    private var book: ShelvedBook? {
        ShelvedBook.find(CatalogueWork(id: work.id, editions: work.editions + (details?.editions ?? [])), among: shelves)
    }

    /// A book entered by hand reads from what the reader entered, which they can
    /// change while the page is open.
    private var base: CatalogueWork {
        if let book, book.source == .hand { return book.work }
        return work
    }

    /// The work with every edition once they have loaded. A page opened from a shelf
    /// starts with only the edition that was shelved.
    private var shown: CatalogueWork {
        guard !enteredByHand, let editions = details?.editions, !editions.isEmpty else { return base }
        return CatalogueWork(id: base.id, editions: editions)
    }

    private var newest: CatalogueEdition { shown.editions[0] }

    /// Whether the catalogue has the book. One entered by hand or found on Open
    /// Library has no editions, ESTER record or library copies to show.
    private var fromCatalogue: Bool { shown.editions.contains { !$0.erbID.isEmpty } }

    /// Open Library's cover, for a book found there. A catalogue book has none.
    static func coverArt(for work: CatalogueWork) -> CoverArt? {
        work.editions[0].openLibrary.flatMap(CoverArt.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                BookHeader(
                    work: shown, edition: newest, book: book, art: Self.coverArt(for: base),
                    credit: book?.coverPhoto == nil && openLibraryCover != nil
                ) { openLibraryCover = $0 }
                // A book entered by hand that was just removed is on its way off screen.
                if book != nil || !enteredByHand {
                    ShelfControls(work: shown, edition: newest, book: book)
                }
                if newest.originalTitle != nil {
                    OriginalCard(edition: newest, original: details?.original)
                }
                if let details {
                    // With no author, a title alone would match unrelated books.
                    if !details.translations.isEmpty && (shown.authors != nil || fromCatalogue) {
                        WorkRail(title: "Translations", works: details.translations) { work in
                            LanguageName.of(work.language).map { String(localized: "In \($0)") }
                        }
                    }
                    if fromCatalogue {
                        EditionsSection(editions: details.editions)
                    }
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
                if let url = newest.openLibrary?.url {
                    OpenLibraryCredit(url: url)
                }
            }
            // Fill the width even when nothing on the page does, or the scroll
            // view shrinks to the text and its background stops short of the edges.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background {
            // A book's own page takes a soft wash of its cover's colour.
            if let wash = (book?.coverSample ?? openLibraryCover?.sample).flatMap({ CoverWash.color($0, dark: colorScheme == .dark, surface: .page) }) {
                LinearGradient(colors: [wash, .loeBackground], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55))
                    .ignoresSafeArea()
            } else {
                Color.loeBackground.ignoresSafeArea()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if book != nil, enteredByHand {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            if let book {
                EnteredBookSheet("Edit book", book: book.entered) { book.update(from: $0) }
            }
        }
        .onChange(of: book?.source, initial: true) { _, source in
            if source == .hand { enteredByHand = true }
        }
        .onChange(of: book == nil) { _, removed in
            // A book entered by hand exists only on the shelves, so its page goes with it.
            if removed && enteredByHand { dismiss() }
        }
        .task(id: base) {
            guard case .ready(let catalogue) = catalogue.state else { return }
            details = try? await catalogue.details(for: base)
        }
    }
}

/// Open Library asks for a link back, and the reader should know where a book
/// from abroad came from.
private struct OpenLibraryCredit: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This book comes from Open Library, which Loe asked about it.")
                .foregroundStyle(.loeSecondary)
            Link(destination: url) {
                Label("See it on Open Library", systemImage: "arrow.up.right")
                    .labelStyle(.titleAndIcon)
            }
            .tint(.loeAccent)
        }
        .font(.footnote)
    }
}

private struct BookHeader: View {
    let work: CatalogueWork
    let edition: CatalogueEdition
    let book: ShelvedBook?
    let art: CoverArt?
    /// Whether Open Library's cover is showing, which is credited under it.
    let credit: Bool
    let onCover: (Covers.Loaded?) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                if let book {
                    CoverPhotoMenu(book: book, title: work.title, art: art, width: 140, onCover: onCover)
                } else {
                    BookCover(title: work.title, art: art, width: 140, onCover: onCover)
                }
                if credit {
                    Text("Cover: Open Library")
                        .font(.caption2)
                        .foregroundStyle(.loeSecondary)
                }
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
