import SwiftData
import SwiftUI

/// Books to read next, each with the reason Loe suggests it, worked out from the
/// reader's own shelves.
struct ReadNextView: View {
    @Environment(CatalogueStore.self) private var catalogue
    @Environment(\.modelContext) private var context
    @Query private var books: [ShelvedBook]
    @State private var loaded: Loaded?
    @State private var path = NavigationPath()

    private struct Loaded {
        let sources: [ReadNext.Source]
        let suggestions: [ReadNextSuggestion]
    }

    /// What the suggestions depend on. A page update or a book added to Want to read
    /// changes neither, so it does not start the work again.
    private struct Input: Equatable {
        let sources: [ReadNext.Source]
        let catalogue: ObjectIdentifier?
    }

    var body: some View {
        let sources = ReadNext.sources(from: books)
        NavigationStack(path: $path) {
            Group {
                if case .ready = catalogue.state {
                    content(sources: sources)
                } else {
                    EmptyState(
                        title: "Suggestions need the catalogue",
                        systemImage: "sparkles",
                        description: "Download it in Search, then give the books you've read a rating."
                    )
                }
            }
            .navigationTitle("Read next")
            .navigationDestination(for: CatalogueWork.self) { BookView(work: $0) }
        }
        .task(id: Input(sources: sources, catalogue: readyCatalogue.map(ObjectIdentifier.init))) {
            guard let readyCatalogue else { return }
            let shelved = ReadNext.shelved(books)
            guard let suggestions = try? await ReadNext.suggestions(from: sources, excluding: shelved, in: readyCatalogue),
                  !Task.isCancelled
            else { return }
            loaded = Loaded(sources: sources, suggestions: suggestions)
        }
    }

    private var readyCatalogue: Catalogue? {
        if case .ready(let catalogue) = catalogue.state { catalogue } else { nil }
    }

    @ViewBuilder
    private func content(sources: [ReadNext.Source]) -> some View {
        let shelved = ReadNext.shelved(books)
        let suggestions = loaded?.suggestions.filter { !ReadNext.isOnShelf($0.work, shelved) }
        if let suggestions, !suggestions.isEmpty {
            ScrollView {
                ReadNextList(suggestions: suggestions) { suggestion in
                    path.append(suggestion.work)
                } wantToRead: { suggestion in
                    let work = suggestion.work
                    _ = try? ShelvedBook.shelve(work, edition: work.editions[0], on: .wantToRead, in: context)
                }
            }
            .background(.loeBackground)
        } else if !sources.isEmpty && loaded?.sources != sources {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.loeBackground)
        } else if !sources.contains(where: \.isFavourite) {
            EmptyState(
                title: "Nothing to suggest yet",
                systemImage: "sparkles",
                description: "Give a book you've read four or five stars, and Loe will suggest more like it."
            )
        } else {
            EmptyState(
                title: "Nothing to suggest yet",
                systemImage: "sparkles",
                description: "Loe found nothing close enough to the books you rated highly. Rate a few more."
            )
        }
    }
}

/// The suggestions, the first one larger with a button to keep it for later.
struct ReadNextList: View {
    let suggestions: [ReadNextSuggestion]
    let open: (ReadNextSuggestion) -> Void
    let wantToRead: (ReadNextSuggestion) -> Void

    var body: some View {
        LazyVStack(spacing: 14) {
            if let first = suggestions.first {
                FeaturedSuggestion(suggestion: first) { open(first) } wantToRead: { wantToRead(first) }
            }
            ForEach(suggestions.dropFirst()) { suggestion in
                SuggestionRow(suggestion: suggestion) { open(suggestion) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct FeaturedSuggestion: View {
    let suggestion: ReadNextSuggestion
    let open: () -> Void
    let wantToRead: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        CoverBeside(stacked: dynamicTypeSize.isAccessibilitySize) {
            Button(action: open) {
                BlankCover(title: suggestion.work.title, width: 112)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                ReasonLabel(reason: suggestion.reason)
                Button(action: open) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.work.title)
                            .loeHeading(.section)
                            .foregroundStyle(.loeInk)
                            .multilineTextAlignment(.leading)
                        if let authors = suggestion.work.authors {
                            Text(authors.replacingOccurrences(of: "; ", with: ", "))
                                .foregroundStyle(.loeSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("featuredSuggestion")
                Button(action: wantToRead) {
                    Text(Shelf.wantToRead.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.loeOnAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.loeAccent, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.loeCard, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.loeHairline))
    }
}

private struct SuggestionRow: View {
    let suggestion: ReadNextSuggestion
    let open: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: open) {
            CoverBeside(stacked: dynamicTypeSize.isAccessibilitySize) {
                BlankCover(title: suggestion.work.title, width: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.work.title)
                        .loeHeading(.inline)
                        .foregroundStyle(.loeInk)
                        .multilineTextAlignment(.leading)
                    if let authors = suggestion.work.authors {
                        Text(authors.replacingOccurrences(of: "; ", with: ", "))
                            .foregroundStyle(.loeSecondary)
                    }
                    ReasonLabel(reason: suggestion.reason)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(.loeCard, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.loeHairline))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// A cover with the text beside it, or above it at the largest text sizes, where
/// beside it the text would get a word or two a line.
private struct CoverBeside<Content: View>: View {
    let stacked: Bool
    @ViewBuilder var content: Content

    var body: some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout { content }
    }
}

/// Why a book is suggested, naming the reader's own book where there is one.
struct ReasonLabel: View {
    let reason: ReadNextSuggestion.Reason

    var body: some View {
        Label {
            Self.text(for: reason)
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: Self.symbol(for: reason))
        }
        .font(.subheadline)
        .foregroundStyle(.loeAccent)
    }

    static func symbol(for reason: ReadNextSuggestion.Reason) -> String {
        switch reason {
        case .nextInSeries: "books.vertical.fill"
        case .sameAuthor: "person.fill"
        case .similar: "tag.fill"
        }
    }

    static func text(for reason: ReadNextSuggestion.Reason) -> Text {
        switch reason {
        case .nextInSeries(let book):
            Text("Next after \(title(book))")
        case .sameAuthor(let book):
            Text("More by the author of \(title(book))")
        case .similar(let books) where books.count == 1:
            Text("Shares themes with \(title(books[0]))")
        case .similar(let books):
            Text("Shares themes with \(books.count) of your favourites")
        }
    }

    /// Estonian titles go in „marks“, English ones in italics.
    private static func title(_ book: ReadNextSuggestion.Book) -> Text {
        book.language == "eng" ? Text(book.title).italic() : Text(verbatim: "„\(book.title)“")
    }
}

#Preview {
    ReadNextView()
        .environment(CatalogueStore())
        .modelContainer(for: ShelvedBook.self, inMemory: true)
}
