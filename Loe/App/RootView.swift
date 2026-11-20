import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(TasteQuiz.seenKey) private var quizSeen = false
    @Environment(\.modelContext) private var context
    @Environment(CloudSync.self) private var cloudSync
    @Query private var tastes: [Taste]
    @State private var showsQuiz = false

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
        .sheet(isPresented: $showsQuiz, onDismiss: { quizSeen = true }) {
            TasteQuiz()
        }
        .onAppear {
            // Tastes synced from another device mean the reader has answered already.
            showsQuiz = !quizSeen && tastes.isEmpty
        }
        // Two devices can each shelve a book while apart, which leaves two records
        // of it once they sync.
        .task(id: cloudSync.lastSynced) {
            #if DEBUG
            LibraryStore.insertDuplicatesIfAsked(into: context)
            #endif
            _ = try? ShelvedBook.mergeDuplicates(in: context)
        }
    }
}

#Preview {
    RootView()
        .environment(CatalogueStore())
        .environment(CloudSync())
        .modelContainer(for: [ShelvedBook.self, Taste.self, ChosenPlace.self], inMemory: true)
}
