import SwiftData
import SwiftUI

/// On a book's page: which shelf it is on, its rating once read, and how far
/// the reader has got while reading it.
struct ShelfControls: View {
    let work: CatalogueWork
    let edition: CatalogueEdition

    @Environment(\.modelContext) private var context
    @Query private var matches: [ShelvedBook]
    @State private var editingPage = false

    init(work: CatalogueWork, edition: CatalogueEdition) {
        self.work = work
        self.edition = edition
        let key = work.id
        _matches = Query(filter: #Predicate<ShelvedBook> { $0.workKey == key })
    }

    var body: some View {
        if let book = matches.first {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    shelfMenu(current: book) {
                        HStack(spacing: 8) {
                            ShelfMark(shelf: book.shelf)
                            Text(book.shelf.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.loeInk)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.loeSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.loeCard, in: .capsule)
                        .overlay(Capsule().strokeBorder(.loeHairline))
                    }
                    .accessibilityLabel(Text("Shelf: \(book.shelf.name)"))
                    if book.shelf == .read || book.shelf == .didNotFinish {
                        RatingStars(rating: book.rating) { book.rate($0) }
                    }
                }
                if book.shelf == .reading {
                    ReadingProgress(book: book) { editingPage = true }
                }
            }
            .sheet(isPresented: $editingPage) {
                PageSheet(book: book)
            }
        } else {
            shelfMenu(current: nil) {
                Text("Add to shelf")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.loeOnAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.loeAccent, in: .capsule)
            }
        }
    }

    private func shelfMenu(current: ShelvedBook?, @ViewBuilder label: () -> some View) -> some View {
        Menu {
            ForEach(Shelf.allCases, id: \.self) { shelf in
                Button {
                    _ = try? ShelvedBook.shelve(work, edition: edition, on: shelf, in: context)
                } label: {
                    if shelf == current?.shelf {
                        Label { Text(shelf.name) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(shelf.name)
                    }
                }
            }
            if let current {
                Divider()
                Button(role: .destructive) {
                    context.delete(current)
                } label: {
                    Text("Remove from shelves")
                }
            }
        } label: {
            label()
        }
    }
}

struct ReadingProgress: View {
    let book: ShelvedBook
    var onUpdate: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: book.progress ?? 0)
                .tint(.loeAccent)
            HStack {
                Text(Self.pageText(book))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.loeSecondary)
                Spacer()
                if let onUpdate {
                    Button("Update page", action: onUpdate)
                        .font(.subheadline.weight(.semibold))
                        .tint(.loeAccent)
                }
            }
        }
    }

    static func pageText(_ book: ShelvedBook) -> String {
        switch (book.currentPage, book.pageCount) {
        case let (page?, pages?): String(localized: "p. \(page) of \(pages)")
        case let (page?, nil): String(localized: "p. \(page)")
        default: String(localized: "Not started")
        }
    }
}

private struct PageSheet: View {
    let book: ShelvedBook
    @Environment(\.dismiss) private var dismiss
    @State private var page: Int?
    @State private var pages: Int?

    var body: some View {
        NavigationStack {
            Form {
                number("Page you're on", $page)
                number("Pages in the book", $pages)
            }
            .navigationTitle("Update page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        book.setPage(page ?? 0, of: pages)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            page = book.currentPage
            pages = book.pageCount
        }
    }

    private func number(_ label: LocalizedStringKey, _ value: Binding<Int?>) -> some View {
        LabeledContent {
            TextField(label, value: value, format: .number, prompt: Text(verbatim: "–"))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .accessibilityLabel(Text(label))
        } label: {
            Text(label)
        }
    }
}
