import SwiftData
import SwiftUI

@main
struct LoeApp: App {
    @AppStorage(LoeAppearance.storageKey) private var appearance = LoeAppearance.system
    @AppStorage(LoeLanguage.storageKey) private var language = LoeLanguage.system
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
                        .task { await catalogue.updateIfDue() }
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
