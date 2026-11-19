import Foundation
import SwiftData

/// The reader's shelves on disk, synced through their own iCloud when the app is
/// signed for it.
enum LibraryStore {
    static func makeContainer() -> ModelContainer {
        #if DEBUG
        // Journeys start from empty shelves and leave nothing behind.
        if UserDefaults.standard.bool(forKey: "inMemoryLibrary") {
            return open(ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
        #endif
        return open(ModelConfiguration(cloudKitDatabase: .automatic))
    }

    private static func open(_ configuration: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: ShelvedBook.self, Taste.self, ChosenPlace.self, configurations: configuration)
        } catch {
            fatalError("The library could not be opened: \(error)")
        }
    }
}
