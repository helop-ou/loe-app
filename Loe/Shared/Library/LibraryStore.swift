import CoreData
import Foundation
import SwiftData

/// The reader's shelves on disk, synced through their own iCloud when the app is
/// signed for it.
enum LibraryStore {
    static let models: [any PersistentModel.Type] = [ShelvedBook.self, Taste.self, ChosenPlace.self]

    static func makeContainer() -> ModelContainer {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "initializeCloudKitSchema") {
            initializeCloudKitSchema()
        }
        // Journeys start from empty shelves and leave nothing behind.
        if UserDefaults.standard.bool(forKey: "inMemoryLibrary") {
            return open(ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
        #endif
        return open(ModelConfiguration(cloudKitDatabase: .automatic))
    }

    private static func open(_ configuration: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: Schema(models), configurations: configuration)
        } catch {
            fatalError("The library could not be opened: \(error)")
        }
    }

    #if DEBUG
    /// Teaches CloudKit's Development environment every synced model and field, from
    /// a throwaway store so the reader's shelves are not touched. Deploy it to
    /// Production afterwards. See docs/release.md, "Uploading to TestFlight".
    private static func initializeCloudKitSchema() {
        let url = FileManager.default.temporaryDirectory.appending(path: "schema-\(UUID().uuidString).store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.ee.helop.loe")
        description.shouldAddStoreAsynchronously = false
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: models) else {
            print("CloudKit schema: the model could not be built")
            return
        }
        let container = NSPersistentCloudKitContainer(name: "Schema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        do {
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema()
            print("CloudKit schema: Development now has every synced model")
        } catch {
            print("CloudKit schema: failed: \(error)")
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        try? FileManager.default.removeItem(at: url)
    }
    #endif
}
