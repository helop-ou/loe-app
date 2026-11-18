import SwiftUI

struct SearchView: View {
    @Environment(CatalogueStore.self) private var catalogue
    @State private var query = ""
    @State private var results: [CatalogueWork] = []
    @State private var resultsQuery = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .navigationDestination(for: CatalogueWork.self) { BookView(work: $0) }
                .searchable(text: $query, prompt: "Title, author or ISBN")
                .task(id: query) { await search() }
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
            } else if results.isEmpty && resultsQuery == trimmed {
                EmptyState(
                    title: "No books found",
                    systemImage: "magnifyingglass",
                    description: "Check the spelling, or try the author's name."
                )
            } else {
                List(results) { work in
                    NavigationLink(value: work) {
                        SearchResultRow(work: work)
                    }
                    .listRowBackground(Color.loeBackground)
                        .listRowSeparatorTint(.loeHairline)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(.loeBackground)
            }
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard case .ready(let catalogue) = catalogue.state, !trimmed.isEmpty else {
            results = []
            resultsQuery = trimmed
            return
        }
        // Wait for a pause in typing. A new keystroke cancels this task.
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        let found = (try? await catalogue.search(trimmed)) ?? []
        guard !Task.isCancelled else { return }
        results = found
        resultsQuery = trimmed
    }
}

#Preview {
    SearchView()
        .environment(CatalogueStore())
}
