import Foundation
import SwiftData

/// The reader's shelves on disk, synced through their own iCloud when the app is
/// signed for it.
enum LibraryStore {
    static func makeContainer() -> ModelContainer {
        var inMemory = false
        #if DEBUG
        // Journeys start from empty shelves and leave nothing behind.
        inMemory = UserDefaults.standard.bool(forKey: "inMemoryLibrary")
        #endif
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
        do {
            return try ModelContainer(for: ShelvedBook.self, configurations: configuration)
        } catch {
            fatalError("The library could not be opened: \(error)")
        }
    }
}
