import SwiftUI

@main
struct LoeApp: App {
    @AppStorage(LoeAppearance.storageKey) private var appearance = LoeAppearance.system

    init() {
        NavigationTitles.applyNewsreader()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
