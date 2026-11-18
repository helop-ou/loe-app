import SwiftData
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Shelves", systemImage: "books.vertical") {
                ShelvesView()
            }
            Tab("Read next", systemImage: "sparkles") {
                ReadNextView()
            }
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }
        }
        .tint(.loeAccent)
    }
}

#Preview {
    RootView()
        .environment(CatalogueStore())
        .modelContainer(for: ShelvedBook.self, inMemory: true)
}
