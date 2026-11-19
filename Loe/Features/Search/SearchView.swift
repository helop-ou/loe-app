import SwiftData
import SwiftUI

struct SearchView: View {
    /// What the add form starts from, each time it opens.
    private struct Adding: Identifiable {
        let id = UUID()
        let entry: EnteredBook
    }

    /// Books from abroad, found on Open Library once typing pauses.
    enum Online: Equatable {
        case notAsked
        case searching
        case found([OpenLibraryBook])
        case failed
    }

    var openLibrary = OpenLibrary.live

    @Environment(CatalogueStore.self) private var catalogue
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var results: [CatalogueWork] = []
    @State private var resultsQuery = ""
    @State private var online: Online = .notAsked
    @State private var scanning = false
    @State private var adding: Adding?
    @State private var path: [CatalogueWork] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Search")
                .navigationDestination(for: CatalogueWork.self) { BookView(work: $0) }
                .searchable(text: $query, prompt: "Title, author or ISBN")
                .task(id: query) { await search() }
                .toolbar {
                    if BarcodeScanner.isSupported, case .ready = catalogue.state {
                        Button("Scan a barcode", systemImage: "barcode.viewfinder") { scanning = true }
                    }
                }
                .sheet(isPresented: $scanning) {
                    ScanSheet { query = $0 }
                }
                .sheet(item: $adding) { adding in
                    EnteredBookSheet("Add a book", book: adding.entry) { book in
                        // A book entered by hand lives on a shelf, so it starts on Want to read.
                        let shelved = ShelvedBook.add(book, on: .wantToRead, in: context)
                        path.append(shelved.work)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        switch catalogue.state {
        case .missing:
            CatalogueDownloadView()
        case .unreadable:
            EmptyState(
                title: "The catalogue can't be read",
                systemImage: "exclamationmark.triangle",
                description: "It may be from a newer version of Loe."
            )
        case .ready:
            if trimmed.isEmpty {
                EmptyState(
                    title: "Find a book",
                    systemImage: "magnifyingglass",
                    description: "Search by title, author or ISBN."
                )
            } else if results.isEmpty && resultsQuery == trimmed && CatalogueQuery.isbn13(trimmed) != nil {
                EmptyState(
                    title: "No book with this ISBN",
                    systemImage: "barcode",
                    description: "The catalogue has the books published in Estonia. Try the title, or add the book yourself."
                ) {
                    addButton(trimmed)
                }
            } else if results.isEmpty && resultsQuery == trimmed && (online == .notAsked || online == .found([])) {
                EmptyState(
                    title: "No books found",
                    systemImage: "magnifyingglass",
                    description: "Check the spelling, try the author's name, or add the book yourself."
                ) {
                    addButton(trimmed)
                }
            } else {
                resultsList(trimmed)
            }
        }
    }

    private func resultsList(_ trimmed: String) -> some View {
        List {
            ForEach(results) { work in
                NavigationLink(value: work) {
                    SearchResultRow(work: work)
                }
                .listRowBackground(Color.loeBackground)
                .listRowSeparatorTint(.loeHairline)
            }
            if resultsQuery == trimmed {
                onlineSection
                Button {
                    add(trimmed)
                } label: {
                    Label("Can't find it? Add it yourself", systemImage: "plus")
                        .foregroundStyle(.loeAccent)
                }
                .listRowBackground(Color.loeBackground)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.loeBackground)
    }

    @ViewBuilder
    private var onlineSection: some View {
        switch online {
        case .notAsked, .found([]):
            EmptyView()
        case .searching:
            onlineSection {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching Open Library…")
                        .foregroundStyle(.loeSecondary)
                }
            }
        case .failed:
            onlineSection {
                Text("Open Library can't be reached right now.")
                    .foregroundStyle(.loeSecondary)
            }
        case .found(let books):
            onlineSection {
                ForEach(books) { book in
                    NavigationLink(value: book.work) {
                        SearchResultRow(work: book.work)
                    }
                    .listRowSeparatorTint(.loeHairline)
                }
            }
        }
    }

    private func onlineSection(@ViewBuilder rows: () -> some View) -> some View {
        Section {
            rows()
                .listRowBackground(Color.loeBackground)
            // A row rather than the section's footer, which a plain list paints in
            // the system's own colour.
            Text("Books published abroad. Loe asks Open Library about what you search for, and nothing else.")
                .font(.footnote)
                .foregroundStyle(.loeSecondary)
                .listRowBackground(Color.loeBackground)
                .listRowSeparator(.hidden)
        } header: {
            Text("From Open Library")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.loeSecondary)
        }
    }

    private func addButton(_ text: String) -> some View {
        Button { add(text) } label: {
            Text("Add it yourself")
                .foregroundStyle(.loeOnAccent)
        }
        .buttonStyle(.borderedProminent)
        .tint(.loeAccent)
    }

    private func add(_ text: String) {
        adding = Adding(entry: EnteredBook(searchedFor: text))
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard case .ready(let catalogue) = catalogue.state, !trimmed.isEmpty else {
            results = []
            resultsQuery = trimmed
            online = .notAsked
            return
        }
        // Wait for a pause in typing. A new keystroke cancels this task.
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        let found = (try? await catalogue.search(trimmed)) ?? []
        guard !Task.isCancelled else { return }
        results = found
        resultsQuery = trimmed
        guard OpenLibrary.asksAbout(trimmed) else {
            online = .notAsked
            return
        }
        // Back from a book's page, the answer is already known.
        if let known = await openLibrary.known(trimmed) {
            online = .found(OpenLibraryBook.unseen(known, besides: found))
            return
        }
        online = .searching
        do {
            guard let books = try await openLibrary.search(for: trimmed), !Task.isCancelled else { return }
            online = .found(OpenLibraryBook.unseen(books, besides: found))
        } catch {
            if !Task.isCancelled { online = .failed }
        }
    }
}

#Preview {
    SearchView()
        .environment(CatalogueStore())
        .modelContainer(for: [ShelvedBook.self, Taste.self, ChosenPlace.self], inMemory: true)
}
