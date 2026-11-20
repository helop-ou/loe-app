import Foundation
import SwiftData
import Testing
@testable import Loe

struct StoredNamesTests {
    private static let monday = Date(timeIntervalSince1970: 1_800_000_000)
    private static let scripts = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "scripts")

    private func lines(of name: String) throws -> [String] {
        let text = try String(contentsOf: Self.scripts.appending(path: name), encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    @Test func theSyncedModelsAreThreeEntities() {
        let names = Schema(LibraryStore.models).entities.map(\.name).sorted()
        #expect(names == ["ChosenPlace", "ShelvedBook", "Taste"])
    }

    @Test func theSyncedModelsAreTheOnesWrittenDown() throws {
        let stored = Schema(LibraryStore.models).entities.flatMap { entity in
            entity.attributes.map { "\(entity.name).\($0.name): \(String(describing: $0.valueType))" }
        }.sorted()
        #expect(stored == (try lines(of: "synced-models.txt")), "The synced models changed. Add the change to scripts/synced-models.txt, and never rename or remove a line: records in iCloud use these names. Before the next TestFlight build, deploy the CloudKit schema to Production and copy that file over scripts/synced-models.deployed.txt. See docs/release.md.")
    }

    @Test func nothingProductionHasWasRenamedOrRemoved() throws {
        let written = Set(try lines(of: "synced-models.txt"))
        let missing = try lines(of: "synced-models.deployed.txt").filter { !written.contains($0) }
        #expect(missing.isEmpty, "A synced property Production already has was renamed or removed. Records in iCloud outlive app versions, so put it back and add a new property.")
    }

    @Test(arguments: ["synced-models.txt", "synced-models.deployed.txt"])
    func theListsAreSortedAndHaveNoRepeats(file: String) throws {
        let found = try lines(of: file)
        #expect(found == Array(Set(found)).sorted(), "\(file) must be sorted, with no repeated line.")
    }

    @Test func rawValuesStayAsShipped() {
        #expect(Shelf.allCases.map(\.rawValue) == ["reading", "wantToRead", "read", "setAside", "didNotFinish"])
        #expect(ShelvedBook.Source.catalogue.rawValue == "catalogue")
        #expect(ShelvedBook.Source.hand.rawValue == "hand")
        #expect(ShelvedBook.Source.openLibrary.rawValue == "openLibrary")
        #expect(Genre.allCases.map(\.rawValue) == [
            "crime", "thriller", "psychological", "romance", "drama", "historical",
            "fantasy", "scienceFiction", "horror", "humour", "poetry", "youngAdult",
        ])
    }

    @Test func aShelfNoVersionKnowsReadsAsWantToRead() {
        let book = ShelvedBook(entered: EnteredBook(title: "Kevade"), shelf: .reading)
        book.shelfName = "lent"
        #expect(book.shelf == .wantToRead)
    }

    @Test func aSourceNoVersionKnowsOrNoneReadsAsTheCatalogue() {
        let book = ShelvedBook(entered: EnteredBook(title: "Kevade"), shelf: .reading)
        book.sourceName = "audiobook"
        #expect(book.source == .catalogue)
        book.sourceName = nil
        #expect(book.source == .catalogue)
    }

    @Test func everyStoredPropertyReadsBackFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "stored-names-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "Library.store")
        let photo = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03])
        let schema = Schema(LibraryStore.models)

        do {
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: file, cloudKitDatabase: .none))
            let context = ModelContext(container)
            let book = ShelvedBook(entered: EnteredBook(title: "Kevade"), shelf: .reading)
            book.workKey = "work-7"
            book.erbID = "erb-8"
            book.title = "Kevade"
            book.subtitle = "Pildikesi lapsepõlvest"
            book.authors = "Oskar Luts"
            book.shelfName = "didNotFinish"
            book.rating = 4
            book.currentPage = 120
            book.pageCount = 260
            book.addedAt = Self.monday
            book.startedAt = Self.monday.addingTimeInterval(86_400)
            book.finishedAt = Self.monday.addingTimeInterval(172_800)
            book.updatedAt = Self.monday.addingTimeInterval(259_200)
            book.coverPhoto = photo
            book.coverHue = 0.37
            book.coverSaturation = 0.62
            book.sourceName = "openLibrary"
            book.year = 1912
            book.language = "est"
            book.openLibraryKey = "/works/OL18626W"
            book.isbn = "9789985000000"
            book.coverID = 4242
            context.insert(book)
            context.insert(Taste(genre: .poetry, now: Self.monday.addingTimeInterval(1)))
            context.insert(ChosenPlace(place: .apollo, position: 2.5, now: Self.monday.addingTimeInterval(2)))
            try context.save()
        }

        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: file, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let book = try #require(try context.fetch(FetchDescriptor<ShelvedBook>()).first)
        #expect(book.workKey == "work-7")
        #expect(book.erbID == "erb-8")
        #expect(book.title == "Kevade")
        #expect(book.subtitle == "Pildikesi lapsepõlvest")
        #expect(book.authors == "Oskar Luts")
        #expect(book.shelfName == "didNotFinish")
        #expect(book.rating == 4)
        #expect(book.currentPage == 120)
        #expect(book.pageCount == 260)
        #expect(book.addedAt == Self.monday)
        #expect(book.startedAt == Self.monday.addingTimeInterval(86_400))
        #expect(book.finishedAt == Self.monday.addingTimeInterval(172_800))
        #expect(book.updatedAt == Self.monday.addingTimeInterval(259_200))
        #expect(book.coverPhoto == photo)
        #expect(book.coverHue == 0.37)
        #expect(book.coverSaturation == 0.62)
        #expect(book.sourceName == "openLibrary")
        #expect(book.year == 1912)
        #expect(book.language == "est")
        #expect(book.openLibraryKey == "/works/OL18626W")
        #expect(book.isbn == "9789985000000")
        #expect(book.coverID == 4242)

        let taste = try #require(try context.fetch(FetchDescriptor<Taste>()).first)
        #expect(taste.genreName == "poetry")
        #expect(taste.addedAt == Self.monday.addingTimeInterval(1))

        let chosen = try #require(try context.fetch(FetchDescriptor<ChosenPlace>()).first)
        #expect(chosen.placeID == "shop.apollo")
        #expect(chosen.position == 2.5)
        #expect(chosen.addedAt == Self.monday.addingTimeInterval(2))
    }
}
