import SwiftData
import SwiftUI

@main
struct LoeApp: App {
    @AppStorage(LoeAppearance.storageKey) private var appearance = LoeAppearance.system
    @State private var catalogue = CatalogueStore()
    @State private var cloudSync = CloudSync()
    private let library = LibraryStore.makeContainer()

    init() {
        NavigationTitles.applyNewsreader()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalogue)
                .environment(cloudSync)
                .task { await catalogue.updateIfDue() }
                .task { await cloudSync.start() }
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(library)
    }
}
