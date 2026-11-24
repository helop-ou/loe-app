import Foundation
import SwiftData
import Testing
@testable import Loe

struct ShelvedOpenLibraryBookTests {
    private let context: ModelContext
    private let halo = OpenLibraryBook(
        record: OpenLibraryRecord(workKey: "/works/OL18626W", isbn: "9780345451323", coverID: 210_551),
        title: "Halo: The Fall of Reach", authors: ["Eric S. Nylund"], year: 2001, pages: 339, language: "eng"
    )

    init() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    @Test func aBookFromOpenLibraryKeepsWhereItCameFrom() throws {
        let work = halo.work
        let book = try ShelvedBook.shelve(work, edition: work.editions[0], on: .reading, in: context)
        #expect(book.source == .openLibrary)
        #expect(book.erbID.isEmpty)
        #expect(book.openLibraryKey == "/works/OL18626W")
        #expect(book.isbn == "9780345451323")
        #expect(book.coverID == 210_551)
        #expect(book.year == 2001)
        #expect(book.language == "eng")
        #expect(book.pageCount == 339)
        // Opened again from the shelf, it is still Open Library's book.
        #expect(book.work.editions[0].openLibrary == halo.record)
        #expect(book.work.id == work.id)
    }

    @Test func aBookFromOpenLibraryHasItsCover() throws {
        let book = try ShelvedBook.shelve(halo.work, edition: halo.work.editions[0], on: .read, in: context)
        #expect(book.coverArt == .id(210_551))
    }

    @Test func aCatalogueBookAsksESTERForTheEditionThatWasShelved() throws {
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        let newer = CatalogueEdition(id: 2, erbID: "b46590080", title: "Keisri hull", authors: "Jaan Kross")
        let book = try ShelvedBook.shelve(CatalogueWork(id: CatalogueWork.key(for: kross), editions: [newer, kross]), edition: kross, on: .read, in: context)
        #expect(book.coverArt == .ester(["b1054421"]))
    }

    @Test func aBookEnteredByHandHasNoCover() {
        let book = ShelvedBook.add(EnteredBook(title: "Recipes", authors: "Mari Maasikas"), on: .read, in: context)
        #expect(book.coverArt == nil)
    }

    @Test func itIsTheSameBookAsTheCataloguesWithTheSameTitleAndAuthors() throws {
        let fromAbroad = OpenLibraryBook(record: .init(workKey: "/works/OL1W"), title: "The czar's madman", authors: ["Jaan Kross"])
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "The czar's madman", authors: "Jaan Kross")
        try ShelvedBook.shelve(fromAbroad.work, edition: fromAbroad.work.editions[0], on: .wantToRead, in: context)
        try ShelvedBook.shelve(CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross]), edition: kross, on: .read, in: context)
        let books = try context.fetch(FetchDescriptor<ShelvedBook>())
        #expect(books.count == 1)
        #expect(books.first?.shelf == .read)
    }

    private let haloInCatalogue = CatalogueEdition(id: 7, erbID: "b10000001", title: "Halo", subtitle: "The fall of reach", authors: "Eric Nylund")
    private var haloInCatalogueWork: CatalogueWork { CatalogueWork(id: CatalogueWork.key(for: haloInCatalogue), editions: [haloInCatalogue]) }

    private func all() throws -> [ShelvedBook] {
        try context.fetch(FetchDescriptor<ShelvedBook>())
    }

    /// The catalogue keeps "The fall of reach" apart, Open Library puts it in the
    /// title, and only one names the middle initial. It is still one book.
    @Test func theCataloguesCopyIsMovedNotAddedAgain() throws {
        try ShelvedBook.shelve(haloInCatalogueWork, edition: haloInCatalogue, on: .wantToRead, in: context)
        let book = try ShelvedBook.shelve(halo.work, edition: halo.work.editions[0], on: .reading, in: context)
        let books = try all()
        #expect(books.count == 1)
        #expect(book.shelf == .reading)
        #expect(book.source == .catalogue)
        #expect(book.subtitle == "The fall of reach")
    }

    @Test func openLibrarysCopyIsMovedNotAddedAgain() throws {
        try ShelvedBook.shelve(halo.work, edition: halo.work.editions[0], on: .reading, in: context)
        let book = try ShelvedBook.shelve(haloInCatalogueWork, edition: haloInCatalogue, on: .read, in: context)
        #expect(try all().count == 1)
        #expect(book.shelf == .read)
        #expect(book.source == .openLibrary)
    }

    @Test func anotherBookByTheSameAuthorStaysApart() throws {
        try ShelvedBook.shelve(haloInCatalogueWork, edition: haloInCatalogue, on: .read, in: context)
        let strike = OpenLibraryBook(record: .init(workKey: "/works/OL2W"), title: "Halo: First Strike", authors: ["Eric S. Nylund"])
        try ShelvedBook.shelve(strike.work, edition: strike.work.editions[0], on: .wantToRead, in: context)
        #expect(try all().count == 2)
    }

    @Test func theSameTitleByAnotherAuthorStaysApart() throws {
        try ShelvedBook.shelve(haloInCatalogueWork, edition: haloInCatalogue, on: .read, in: context)
        let other = OpenLibraryBook(record: .init(workKey: "/works/OL3W"), title: "Halo: The Fall of Reach", authors: ["Maria Kask"])
        try ShelvedBook.shelve(other.work, edition: other.work.editions[0], on: .wantToRead, in: context)
        #expect(try all().count == 2)
    }

    @Test func aBookEnteredByHandIsNeverMatched() throws {
        ShelvedBook.add(EnteredBook(title: "Halo: The Fall of Reach", authors: "Eric Nylund"), on: .read, in: context)
        try ShelvedBook.shelve(halo.work, edition: halo.work.editions[0], on: .reading, in: context)
        #expect(try all().count == 2)
    }

    @Test func aCatalogueBookHasNoOpenLibraryRecord() throws {
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        let book = try ShelvedBook.shelve(CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross]), edition: kross, on: .read, in: context)
        #expect(book.source == .catalogue)
        #expect(book.openLibraryRecord == nil)
        #expect(book.work.editions[0].openLibrary == nil)
    }

    @Test func aBookOpenLibraryRenamedIsMovedNotAddedAgain() throws {
        try ShelvedBook.shelve(halo.work, edition: halo.work.editions[0], on: .reading, in: context)
        let renamed = OpenLibraryBook(record: halo.record, title: "The Fall of Reach", authors: ["Eric Nylund", "William C. Dietz"]).work
        #expect(renamed.id != halo.work.id)
        let book = try ShelvedBook.shelve(renamed, edition: renamed.editions[0], on: .read, in: context)
        #expect(try all().count == 1)
        #expect(book.shelf == .read)
        #expect(book.title == "Halo: The Fall of Reach")
    }
}
