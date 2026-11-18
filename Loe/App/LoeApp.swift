import SwiftUI

@main
struct LoeApp: App {
    @AppStorage(LoeAppearance.storageKey) private var appearance = LoeAppearance.system
    @State private var catalogue = CatalogueStore()

    init() {
        NavigationTitles.applyNewsreader()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalogue)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
