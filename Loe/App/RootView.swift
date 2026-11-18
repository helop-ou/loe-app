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
            Tab(role: .search) {
                SearchView()
            }
        }
    }
}

#Preview {
    RootView()
}
