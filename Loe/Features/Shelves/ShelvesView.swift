import SwiftUI

struct ShelvesView: View {
    var body: some View {
        NavigationStack {
            EmptyState(
                title: "Your shelves are empty",
                systemImage: "books.vertical",
                description: "Find a book in Search and add it to a shelf."
            )
            .navigationTitle("Shelves")
        }
    }
}

#Preview {
    ShelvesView()
}
