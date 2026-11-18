import SwiftData
import SwiftUI

@main
struct LoeApp: App {
    @AppStorage(LoeAppearance.storageKey) private var appearance = LoeAppearance.system
    @State private var catalogue = CatalogueStore()
    private let library = LibraryStore.makeContainer()

    init() {
        NavigationTitles.applyNewsreader()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalogue)
                .task { await catalogue.updateIfDue() }
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(library)
    }
}
