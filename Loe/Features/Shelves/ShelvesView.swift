import SwiftData
import SwiftUI

/// The reader's shelves: what they are reading first, then a row of covers for
/// each other shelf that has books on it.
struct ShelvesView: View {
    @Query(sort: \ShelvedBook.updatedAt, order: .reverse) private var books: [ShelvedBook]

    private static let rails: [Shelf] = [.wantToRead, .read, .setAside, .didNotFinish]

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    EmptyState(
                        title: "Your shelves are empty",
                        systemImage: "books.vertical",
                        description: "Find a book in Search and add it to a shelf."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(books.filter { $0.shelf == .reading }) { book in
                                NavigationLink(value: book.work) {
                                    ReadingCard(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(Self.rails, id: \.self) { shelf in
                                let onShelf = books.filter { $0.shelf == shelf }
                                if !onShelf.isEmpty {
                                    ShelfRail(shelf: shelf, books: onShelf)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .background(.loeBackground)
                }
            }
            .navigationTitle("Shelves")
            .navigationDestination(for: CatalogueWork.self) { BookView(work: $0) }
            .navigationDestination(for: Shelf.self) { ShelfListView(shelf: $0) }
        }
    }
}

private struct ReadingCard: View {
    let book: ShelvedBook
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            BookCover(title: book.title, photo: book.coverPhoto, width: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(Shelf.reading.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.loeInk)
                Text(book.title)
                    .loeHeading(.inline)
                    .foregroundStyle(.loeInk)
                if let authors = book.authors {
                    Text(authors.replacingOccurrences(of: "; ", with: ", "))
                        .foregroundStyle(.loeSecondary)
                }
                ReadingProgress(book: book)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            book.coverSample.flatMap { CoverWash.color($0, dark: colorScheme == .dark, surface: .card) } ?? .loeCard,
            in: .rect(cornerRadius: 20)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.loeHairline))
        .accessibilityElement(children: .combine)
    }
}

private struct ShelfRail: View {
    let shelf: Shelf
    let books: [ShelvedBook]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: shelf) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(shelf.name)
                        .loeHeading(.section)
                        .foregroundStyle(.loeInk)
                    Text(books.count, format: .number)
                        .foregroundStyle(.loeSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.loeSecondary)
                }
            }
            .buttonStyle(.plain)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(books.prefix(20)) { book in
                        NavigationLink(value: book.work) {
                            BookCover(title: book.title, photo: book.coverPhoto, width: 96)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(book.title))
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

/// Every book on one shelf, most recently changed first.
struct ShelfListView: View {
    let shelf: Shelf
    @Query private var books: [ShelvedBook]

    init(shelf: Shelf) {
        self.shelf = shelf
        let name = shelf.rawValue
        _books = Query(
            filter: #Predicate<ShelvedBook> { $0.shelfName == name },
            sort: \ShelvedBook.updatedAt,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16, alignment: .top)], spacing: 20) {
                ForEach(books) { book in
                    NavigationLink(value: book.work) {
                        VStack(alignment: .leading, spacing: 6) {
                            BookCover(title: book.title, photo: book.coverPhoto, width: 100)
                            Text(book.title)
                                .font(.subheadline)
                                .foregroundStyle(.loeInk)
                                .lineLimit(2)
                            if let rating = book.rating {
                                RatingStars(rating: rating, size: 11)
                            }
                        }
                        .frame(width: 100, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(.loeBackground)
        .navigationTitle(Text(shelf.name))
    }
}

#Preview {
    ShelvesView()
        .environment(CatalogueStore())
        .modelContainer(for: ShelvedBook.self, inMemory: true)
}
