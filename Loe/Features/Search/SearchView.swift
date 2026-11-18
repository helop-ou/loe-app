import SwiftUI

struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Find a book", systemImage: "magnifyingglass")
            } description: {
                Text("Search by title, author or ISBN.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.loeBackground)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Title, author or ISBN")
        }
    }
}

#Preview {
    SearchView()
}
