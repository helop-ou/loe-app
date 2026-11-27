import SwiftData
import SwiftUI

@main
struct LoeApp: App {
    @AppStorage(LoeAppearance.storageKey) private var appearance = LoeAppearance.system
    @AppStorage(LoeLanguage.storageKey) private var language = LoeLanguage.system
    @Environment(\.scenePhase) private var scenePhase
    @State private var catalogue = CatalogueStore()
    @State private var cloudSync = CloudSync()
    @State private var library = Result { try LibraryStore.makeContainer() }

    init() {
        #if DEBUG
        LoeLanguage.forgetIfAsked()
        #endif
        NavigationTitles.applyNewsreader()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch library {
                case .success(let container):
                    RootView()
                        .environment(catalogue)
                        .environment(cloudSync)
                        // At launch, and each time Loe comes back to the front: it can
                        // stay open for weeks, so that counts as a launch for the catalogue.
                        .onChange(of: scenePhase, initial: true) {
                            guard scenePhase == .active else { return }
                            Task { await catalogue.keepUp() }
                        }
                        .task { await cloudSync.start() }
                        .modelContainer(container)
                case .failure:
                    LibraryUnavailableView {
                        library = Result { try LibraryStore.makeContainer() }
                    }
                }
            }
            .environment(\.asksESTER, catalogue.asksESTER)
            .preferredColorScheme(appearance.colorScheme)
            .environment(\.locale, language.locale())
        }
    }
}
