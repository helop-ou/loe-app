import SwiftData
import SwiftUI

/// A book's own page: its cover and title, how it relates to its original or its
/// translations, its editions, and where to get it.
struct BookView: View {
    let work: CatalogueWork

    @Environment(CatalogueStore.self) private var catalogue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var details: Catalogue.Details?
    @State private var editing = false
    @State private var enteredByHand = false
    /// The cover Open Library or ESTER had for the book.
    @State private var foundCover: Covers.Loaded?
    @State private var description: (text: String, source: BookDescription.Source)?
    var openLibrary = OpenLibrary.live
    var covers = Covers.live
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

    /// The cover to look for: Open Library's for a book found there, and ESTER's
    /// for a catalogue book, by its editions in the order given. A book entered by
    /// hand has none.
    static func coverArt(for work: CatalogueWork) -> CoverArt? {
        if let abroad = work.editions[0].openLibrary { return CoverArt(abroad) }
        return CoverArt(erbIDs: work.editions.map(\.erbID), title: work.title)
    }

    /// A catalogue book waits for all its editions, newest first, so that ESTER is
    /// asked about it once.
    private var art: CoverArt? {
        base.editions[0].openLibrary != nil || details != nil ? Self.coverArt(for: shown) : nil
    }

    /// Whose cover is showing, to say so under it. The reader's own photo needs none.
    private var coverCredit: LocalizedStringKey? {
        guard book?.coverPhoto == nil, foundCover != nil, let art else { return nil }
        return art.isESTERs ? "Cover: ESTER" : "Cover: Open Library"
    }

    private struct DescriptionRequest: Equatable {
        let abroad: OpenLibraryRecord?
        let art: CoverArt?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                BookHeader(
                    work: shown, edition: newest, book: book, art: art, credit: coverCredit
                ) { foundCover = $0 }
                // A book entered by hand that was just removed is on its way off screen.
                if book != nil || !enteredByHand {
                    ShelfControls(work: shown, edition: newest, book: book)
                }
                if let tags = details?.tags, !tags.isEmpty {
                    BookTagList(tags: tags)
                }
                if let description {
                    BookDescription(text: description.text, source: description.source)
                }
                if newest.originalTitle != nil {
                    OriginalCard(edition: newest, original: details?.original)
                }
                if let details {
                    // With no author, a title alone would match unrelated books.
                    if !details.translations.isEmpty && (shown.authors != nil || fromCatalogue) {
                        WorkRail(title: "Translations", works: details.translations) { work in
                            LanguageName.of(work.language, in: locale).map { locale.localized("In \($0)") }
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
            if let wash = (book?.coverSample ?? foundCover?.sample).flatMap({ CoverWash.color($0, dark: colorScheme == .dark, surface: .page) }) {
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
        // What the book is about: Open Library's words for a book from abroad, and
        // ESTER's own summary for a catalogue book that has one. With no network it
        // says nothing.
        .task(id: DescriptionRequest(abroad: base.editions[0].openLibrary, art: art)) {
            description = nil
            if let record = base.editions[0].openLibrary {
                description = ((try? await openLibrary.description(of: record)) ?? nil).map { ($0, .openLibrary) }
            } else if let art {
                description = await covers.description(for: art).map { ($0, .ester) }
            }
        }
    }
}

/// What a book is about, in the words of Open Library or ESTER. A long one is cut
/// to a few lines until the reader asks for more, and a short one shows whole, so
/// nothing is cut without a way to read on.
struct BookDescription: View {
    enum Source {
        case openLibrary
        case ester
    }

    let text: String
    var source = Source.openLibrary

    private var credit: LocalizedStringKey {
        source == .ester ? "From ESTER" : "From Open Library"
    }

    @State private var showsAll = false

    /// Longer than this many characters and the text is cut until asked for.
    static let short = 280

    var body: some View {
        let long = text.count > Self.short
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: text)
                .foregroundStyle(.loeInk)
                .lineLimit(long && !showsAll ? 5 : nil)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                if long {
                    Button(showsAll ? "Less" : "More") { showsAll.toggle() }
                        .tint(.loeAccent)
                }
                Spacer()
                Text(credit)
                    .foregroundStyle(.loeSecondary)
            }
            .font(.footnote)
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

struct BookHeader: View {
    let work: CatalogueWork
    let edition: CatalogueEdition
    let book: ShelvedBook?
    let art: CoverArt?
    /// Whose cover is showing, said under it. Nil for the reader's photo or a card.
    let credit: LocalizedStringKey?
    let onCover: (Covers.Loaded?) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                if let book {
                    CoverPhotoMenu(book: book, title: work.title, art: art, width: 140, onCover: onCover)
                } else {
                    BookCover(title: work.title, art: art, width: 140, onCover: onCover)
                }
                if let credit {
                    Text(credit)
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
struct OriginalCard: View {
    let edition: CatalogueEdition
    let original: CatalogueWork?

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let language = LanguageName.of(edition.originalLanguage, in: locale) {
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

/// What kind of book it is, as small labels that wrap onto as many rows as they
/// need. See `BookTags`.
struct BookTagList: View {
    /// Headings as the bibliography spells them.
    let tags: [String]

    @Environment(\.locale) private var locale

    var body: some View {
        WrappingRows(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(HeadingName.of(tag, in: locale))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.loeInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.loeCard, in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.loeHairline))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Rows of views, each row as long as fits. A view wider than a row takes the row's
/// width and wraps inside it.
private struct WrappingRows: Layout {
    let spacing: CGFloat

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(
            width: rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            if !rows[rows.count - 1].items.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            let last = rows.count - 1
            rows[last].width += (rows[last].items.isEmpty ? 0 : spacing) + size.width
            rows[last].height = max(rows[last].height, size.height)
            rows[last].items.append((index, size))
        }
        return rows
    }
}

struct EditionsSection: View {
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
                Button { showsAll = true } label: {
                    // A button centres its lines when they wrap.
                    Text("Show all \(editions.count) editions")
                        .multilineTextAlignment(.leading)
                }
                .tint(.loeAccent)
            }
        }
    }
}

private struct EditionRow: View {
    let edition: CatalogueEdition

    @Environment(\.locale) private var locale

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
            let details = [edition.editionStatement, edition.pages.map { locale.localized("\($0) pages") }]
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
