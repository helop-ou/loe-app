import Foundation
import SwiftData
import Testing
@testable import Loe

struct LibraryStoreTests {
    @Test func aLibraryThatCannotBeOpenedThrowsInsteadOfCrashing() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "not-a-directory")
        try Data("x".utf8).write(to: file)

        let configuration = ModelConfiguration(url: file.appending(path: "library.store"), cloudKitDatabase: .none)
        #expect(throws: (any Error).self) { try LibraryStore.open(configuration) }
    }

    @Test func anInMemoryLibraryOpens() throws {
        let container = try LibraryStore.open(ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let edition = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross", pages: 352)
        let work = CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
        try ShelvedBook.shelve(work, edition: edition, on: .wantToRead, in: context)
        #expect(try context.fetch(FetchDescriptor<ShelvedBook>()).count == 1)
    }
}
