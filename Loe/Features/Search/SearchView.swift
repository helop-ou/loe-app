import SwiftUI

struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            EmptyState(
                title: "Find a book",
                systemImage: "magnifyingglass",
                description: "Search by title, author or ISBN."
            )
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Title, author or ISBN")
        }
    }
}

#Preview {
    SearchView()
}
