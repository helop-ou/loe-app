import Foundation
import SwiftData
import Testing
@testable import Loe

struct EnteredBookTests {
    @Test func itStartsFromWhatTheReaderSearchedFor() {
        #expect(EnteredBook(searchedFor: "  Halo: The Fall of Reach ").title == "Halo: The Fall of Reach")
        // An ISBN is no title.
        #expect(EnteredBook(searchedFor: "0-306-40615-2").title == "")
    }

    @Test func itTidiesWhatTheReaderTyped() {
        let book = EnteredBook(title: "  Halo:  The Fall of Reach ", authors: " Eric  Nylund , , Joseph Staten ")
        #expect(book.cleanTitle == "Halo: The Fall of Reach")
        #expect(book.cleanAuthors == "Eric Nylund; Joseph Staten")
        #expect(EnteredBook(title: "Halo", authors: " , ").cleanAuthors == nil)
    }

    @Test func aBookNeedsATitle() {
        #expect(!EnteredBook(title: "   ", authors: "Eric Nylund").canSave)
        #expect(EnteredBook(title: "Halo").canSave)
    }

    @Test func numbersThatCannotBeRightAreLeftOut() {
        #expect(EnteredBook(title: "Halo", pages: 0).cleanPages == nil)
        #expect(EnteredBook(title: "Halo", pages: 400).cleanPages == 400)
        #expect(EnteredBook(title: "Halo", year: 201).cleanYear == nil)
        #expect(EnteredBook(title: "Halo", year: 3001).cleanYear == nil)
        #expect(EnteredBook(title: "Halo", year: 2001).cleanYear == 2001)
    }
}

struct ShelvedEnteredBookTests {
    private let context: ModelContext
    private let halo = EnteredBook(title: "Halo: The Fall of Reach", authors: "Eric Nylund", pages: 400, year: 2001, language: "eng")

    init() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    private func all() throws -> [ShelvedBook] {
        try context.fetch(FetchDescriptor<ShelvedBook>())
    }

    @Test func aBookEnteredByHandGoesOnTheShelfAsTyped() throws {
        let book = ShelvedBook.add(halo, on: .wantToRead, in: context)
        #expect(book.source == .hand)
        #expect(book.shelf == .wantToRead)
        #expect(book.title == "Halo: The Fall of Reach")
        #expect(book.authors == "Eric Nylund")
        #expect(book.pageCount == 400)
        #expect(book.erbID.isEmpty)
        // Its page opens with what the reader entered.
        let edition = book.work.editions[0]
        #expect(edition.year == 2001)
        #expect(edition.language == "eng")
        #expect(edition.pages == 400)
    }

    @Test func itNeverMergesWithAnotherBook() throws {
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        try ShelvedBook.shelve(CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross]), edition: kross, on: .read, in: context)
        ShelvedBook.add(EnteredBook(title: "Keisri hull", authors: "Jaan Kross"), on: .wantToRead, in: context)
        ShelvedBook.add(EnteredBook(title: "Keisri hull", authors: "Jaan Kross"), on: .wantToRead, in: context)
        let books = try all()
        #expect(books.count == 3)
        #expect(Set(books.map(\.workKey)).count == 3)
        #expect(books.filter { $0.source == .hand }.count == 2)
    }

    /// Records saved before books could be entered by hand have no source.
    @Test func aBookFromTheCatalogueSaysSo() throws {
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        let book = try ShelvedBook.shelve(CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross]), edition: kross, on: .read, in: context)
        #expect(book.sourceName == nil)
        #expect(book.source == .catalogue)
    }

    @Test func editingChangesTheBookButNotWhichBookItIs() throws {
        let monday = Date(timeIntervalSince1970: 1_800_000_000)
        let book = ShelvedBook.add(halo, on: .reading, in: context, now: monday)
        book.setPage(350, of: 400)
        let key = book.workKey

        var changed = book.entered
        #expect(changed == halo)
        changed.title = "Halo: First Strike"
        changed.pages = 300
        changed.language = nil
        book.update(from: changed, now: monday.addingTimeInterval(60))

        #expect(book.workKey == key)
        #expect(book.title == "Halo: First Strike")
        #expect(book.currentPage == 300)
        #expect(book.language == nil)
        #expect(book.startedAt == monday)
        #expect(try all().count == 1)
    }

    @Test func aFinishedBookStaysOnItsLastPage() {
        let book = ShelvedBook.add(halo, on: .read, in: context)
        var changed = book.entered
        changed.pages = 500
        book.update(from: changed)
        #expect(book.currentPage == 500)
    }

    @Test func severalAuthorsReadBackAsTyped() {
        let book = ShelvedBook.add(EnteredBook(title: "Good Omens", authors: "Terry Pratchett, Neil Gaiman"), on: .read, in: context)
        #expect(book.authors == "Terry Pratchett; Neil Gaiman")
        #expect(book.entered.authors == "Terry Pratchett, Neil Gaiman")
    }
}
