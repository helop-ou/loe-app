import SwiftUI

struct ShelvesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Your shelves are empty", systemImage: "books.vertical")
            } description: {
                Text("Find a book in Search and add it to a shelf.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.loeBackground)
            .navigationTitle("Shelves")
        }
    }
}

#Preview {
    ShelvesView()
}
