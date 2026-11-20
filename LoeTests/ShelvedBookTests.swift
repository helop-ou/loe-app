import Foundation
import SwiftData
import Testing
@testable import Loe

struct ShelvedBookTests {
    private let context: ModelContext
    private let edition = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross", pages: 352)
    private var work: CatalogueWork { CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition]) }
    private let monday = Date(timeIntervalSince1970: 1_800_000_000)
    private var friday: Date { monday.addingTimeInterval(4 * 86_400) }

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

    @Test func aBookIsOnOneShelfAtATime() throws {
        try ShelvedBook.shelve(work, edition: edition, on: .wantToRead, in: context)
        let other = CatalogueEdition(id: 2, erbID: "b11453679", title: "Keisri hull", authors: "Jaan Kross", year: 2017)
        try ShelvedBook.shelve(work, edition: other, on: .reading, in: context)
        let books = try all()
        #expect(books.count == 1)
        #expect(books.first?.shelf == .reading)
    }

    @Test func itKeepsWhatTheShelvesShowWithoutTheCatalogue() throws {
        let book = try ShelvedBook.shelve(work, edition: edition, on: .wantToRead, in: context)
        #expect(book.title == "Keisri hull")
        #expect(book.authors == "Jaan Kross")
        #expect(book.pageCount == 352)
        #expect(book.erbID == "b10544215")
    }

    @Test func startingABookRecordsWhenOnce() throws {
        let book = try ShelvedBook.shelve(work, edition: edition, on: .reading, in: context, now: monday)
        book.move(to: .setAside, now: friday)
        book.move(to: .reading, now: friday)
        #expect(book.startedAt == monday)
        #expect(book.updatedAt == friday)
    }

    @Test func finishingABookRecordsWhenAndTurnsToTheLastPage() throws {
        let book = try ShelvedBook.shelve(work, edition: edition, on: .reading, in: context, now: monday)
        book.setPage(100, of: 352)
        book.move(to: .read, now: friday)
        #expect(book.finishedAt == friday)
        #expect(book.currentPage == 352)
        #expect(book.progress == 1)
    }

    @Test func ratingsStayBetweenOneAndFiveStars() throws {
        let book = try ShelvedBook.shelve(work, edition: edition, on: .read, in: context)
        book.rate(7)
        #expect(book.rating == 5)
        book.rate(0)
        #expect(book.rating == 1)
        book.rate(nil)
        #expect(book.rating == nil)
    }

    @Test func thePageStaysWithinTheBook() throws {
        let book = try ShelvedBook.shelve(work, edition: edition, on: .reading, in: context)
        book.setPage(500, of: 352)
        #expect(book.currentPage == 352)
        book.setPage(-3, of: 352)
        #expect(book.currentPage == 0)
        book.setPage(40, of: nil)
        #expect(book.currentPage == 40)
        #expect(book.progress == nil)
    }

    @Test func itOpensTheSameWorkItWasShelvedFrom() throws {
        let book = try ShelvedBook.shelve(work, edition: edition, on: .read, in: context)
        #expect(book.work.id == work.id)
        #expect(CatalogueWork.key(for: book.work.editions[0]) == work.id)
    }

    @Test func shelvesCanBeQueriedByName() throws {
        try ShelvedBook.shelve(work, edition: edition, on: .read, in: context)
        let name = Shelf.read.rawValue
        let read = try context.fetch(FetchDescriptor<ShelvedBook>(predicate: #Predicate { $0.shelfName == name }))
        #expect(read.count == 1)
    }

    @Test func aBookWhoseTitleTheCatalogueCorrectedIsMovedNotAddedAgain() throws {
        let book = try ShelvedBook.shelve(work, edition: edition, on: .read, in: context, now: monday)
        book.rate(5)
        let corrected = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull. Romaan", authors: "Kross, Jaan", pages: 352)
        let correctedWork = CatalogueWork(id: CatalogueWork.key(for: corrected), editions: [corrected])
        #expect(correctedWork.id != work.id)
        let moved = try ShelvedBook.shelve(correctedWork, edition: corrected, on: .setAside, in: context, now: friday)
        #expect(try all().count == 1)
        #expect(moved.shelf == .setAside)
        #expect(moved.rating == 5)
        // It keeps the words it was shelved under.
        #expect(moved.title == "Keisri hull")
        #expect(moved.workKey == work.id)
    }

    @Test func ofTwoCopiesTheOneWithTheSameRecordIsTheReadersBook() throws {
        let sameTitle = ShelvedBook(
            edition: CatalogueEdition(id: 2, erbID: "b11453679", title: "Keisri hull", authors: "Jaan Kross"),
            workKey: work.id, shelf: .wantToRead, now: monday
        )
        let sameRecord = ShelvedBook(edition: edition, workKey: "an older spelling|jaan kross", shelf: .read, now: friday)
        context.insert(sameTitle)
        context.insert(sameRecord)
        #expect(try ShelvedBook.find(work, in: context) === sameRecord)
    }

    @Test func ofTwoCopiesThatMatchAlikeTheFirstShelvedIsTheReadersBook() throws {
        let later = ShelvedBook(edition: edition, workKey: work.id, shelf: .read, now: friday)
        let first = ShelvedBook(edition: edition, workKey: work.id, shelf: .wantToRead, now: monday)
        context.insert(later)
        context.insert(first)
        #expect(try ShelvedBook.find(work, in: context) === first)
        #expect(ShelvedBook.find(work, among: [first, later]) === first)
    }

    @Test func aBookThatIsNotOnAShelfIsNotFound() throws {
        try ShelvedBook.shelve(work, edition: edition, on: .read, in: context)
        let other = CatalogueEdition(id: 3, erbID: "b10000003", title: "Kolme katku vahel", authors: "Jaan Kross")
        #expect(try ShelvedBook.find(CatalogueWork(id: CatalogueWork.key(for: other), editions: [other]), in: context) == nil)
    }
}
