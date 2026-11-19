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

    @Test func itIsTheSameBookAsTheCataloguesWithTheSameTitleAndAuthors() throws {
        let fromAbroad = OpenLibraryBook(record: .init(workKey: "/works/OL1W"), title: "The czar's madman", authors: ["Jaan Kross"])
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "The czar's madman", authors: "Jaan Kross")
        try ShelvedBook.shelve(fromAbroad.work, edition: fromAbroad.work.editions[0], on: .wantToRead, in: context)
        try ShelvedBook.shelve(CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross]), edition: kross, on: .read, in: context)
        let books = try context.fetch(FetchDescriptor<ShelvedBook>())
        #expect(books.count == 1)
        #expect(books.first?.shelf == .read)
    }

    @Test func aCatalogueBookHasNoOpenLibraryRecord() throws {
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        let book = try ShelvedBook.shelve(CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross]), edition: kross, on: .read, in: context)
        #expect(book.source == .catalogue)
        #expect(book.openLibraryRecord == nil)
        #expect(book.work.editions[0].openLibrary == nil)
    }
}
