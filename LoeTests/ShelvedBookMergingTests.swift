import Foundation
import SwiftData
import Testing
@testable import Loe

struct ShelvedBookMergingTests {
    private let context: ModelContext
    private let monday = Date(timeIntervalSince1970: 1_800_000_000)
    private let kevade = CatalogueEdition(id: 1, erbID: "b10544215", title: "Kevade", authors: "Oskar Luts", pages: 260)
    private let laterEdition = CatalogueEdition(id: 2, erbID: "b11453679", title: "Kevade", authors: "Oskar Luts", pages: 300)
    private let halo = OpenLibraryBook(
        record: OpenLibraryRecord(workKey: "/works/OL18626W", isbn: "9780345451323", coverID: 210_551),
        title: "Halo: The Fall of Reach", authors: ["Eric S. Nylund"]
    )

    init() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    private func day(_ days: Double) -> Date {
        monday.addingTimeInterval(days * 86_400)
    }

    @discardableResult
    private func record(_ edition: CatalogueEdition, key: String? = nil, on shelf: Shelf, at date: Date) -> ShelvedBook {
        let book = ShelvedBook(edition: edition, workKey: key ?? CatalogueWork.key(for: edition), shelf: shelf, now: date)
        context.insert(book)
        return book
    }

    private func all() throws -> [ShelvedBook] {
        try context.fetch(FetchDescriptor<ShelvedBook>())
    }

    @Test func twoRecordsOfOneCatalogueRecordBecomeTheOneShelvedFirst() throws {
        let first = record(kevade, on: .wantToRead, at: monday)
        record(kevade, key: "a later spelling|oskar luts", on: .setAside, at: day(2))
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 1)
        #expect(try all().count == 1)
        #expect(try all().first === first)
        #expect(first.workKey == CatalogueWork.key(for: kevade))
        #expect(first.addedAt == monday)
    }

    @Test func twoEditionsOfOneWorkBecomeOne() throws {
        record(kevade, on: .read, at: monday)
        record(laterEdition, on: .read, at: day(1))
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 1)
        #expect(try all().map(\.erbID) == ["b10544215"])
    }

    @Test func twoRecordsOfOneOpenLibraryWorkBecomeOne() throws {
        let renamed = OpenLibraryBook(record: halo.record, title: "The Fall of Reach", authors: ["Eric Nylund"])
        record(halo.work.editions[0], on: .reading, at: monday)
        record(renamed.work.editions[0], on: .read, at: day(1))
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 1)
        #expect(try all().map(\.title) == ["Halo: The Fall of Reach"])
    }

    @Test func theLatestChangeDecidesTheShelf() throws {
        let first = record(kevade, on: .reading, at: monday)
        let second = record(kevade, on: .wantToRead, at: day(1))
        first.move(to: .didNotFinish, now: day(5))
        second.move(to: .setAside, now: day(3))
        try ShelvedBook.mergeDuplicates(in: context)
        #expect(first.shelf == .didNotFinish)
        #expect(first.updatedAt == day(5))
    }

    @Test func nothingTheReaderRecordedIsDropped() throws {
        let first = record(kevade, on: .wantToRead, at: monday)
        let second = record(laterEdition, on: .reading, at: day(1))
        second.setPage(120, of: 300, now: day(2))
        second.rate(4, now: day(2))
        second.coverPhoto = Data([1, 2, 3])
        second.coverHue = 0.4
        second.coverSaturation = 0.6
        second.move(to: .read, now: day(3))
        try ShelvedBook.mergeDuplicates(in: context)
        #expect(try all().count == 1)
        #expect(first.shelf == .read)
        #expect(first.rating == 4)
        #expect(first.currentPage == 300)
        #expect(first.pageCount == 300)
        #expect(first.coverPhoto == Data([1, 2, 3]))
        #expect(first.coverHue == 0.4)
        #expect(first.coverSaturation == 0.6)
        #expect(first.startedAt == day(1))
        #expect(first.finishedAt == day(3))
        #expect(first.addedAt == monday)
        #expect(first.updatedAt == day(3))
    }

    @Test func theFurthestPageStaysWithItsOwnPageCount() throws {
        let first = record(kevade, on: .reading, at: monday)
        let second = record(laterEdition, on: .reading, at: day(1))
        first.setPage(200, of: 260, now: day(2))
        second.setPage(40, of: 300, now: day(4))
        try ShelvedBook.mergeDuplicates(in: context)
        #expect(first.currentPage == 200)
        #expect(first.pageCount == 260)
    }

    @Test func theLatestRatingAndPhotoWinOverEarlierOnes() throws {
        let first = record(kevade, on: .read, at: monday)
        let second = record(kevade, on: .read, at: day(1))
        first.rate(2, now: day(2))
        first.coverPhoto = Data([9])
        second.rate(5, now: day(3))
        second.coverPhoto = Data([7])
        try ShelvedBook.mergeDuplicates(in: context)
        #expect(first.rating == 5)
        #expect(first.coverPhoto == Data([7]))
    }

    @Test func threeRecordsThatShareOnlyInPairsAreOneBook() throws {
        record(kevade, key: "an older spelling|oskar luts", on: .wantToRead, at: monday)
        record(kevade, on: .reading, at: day(1))
        record(laterEdition, on: .read, at: day(2))
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 2)
        #expect(try all().map(\.workKey) == ["an older spelling|oskar luts"])
        #expect(try all().first?.shelf == .read)
    }

    /// The last record shelved shares its catalogue record with one book and its
    /// title with another, which until then looked like two books.
    @Test func aRecordThatLinksTwoBooksMakesThemOne() throws {
        let first = record(kevade, key: "an older spelling|oskar luts", on: .wantToRead, at: monday)
        record(laterEdition, on: .reading, at: day(1))
        record(kevade, on: .read, at: day(2))
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 2)
        #expect(try all().count == 1)
        #expect(try all().first === first)
        #expect(first.shelf == .read)
    }

    @Test func itComesOutTheSameWhicheverRecordIsSeenFirst() throws {
        let second = record(laterEdition, on: .read, at: day(1))
        second.rate(5, now: day(1))
        let first = record(kevade, on: .wantToRead, at: monday)
        #expect(ShelvedBook.duplicates(among: [second, first]).map { $0.map(\.erbID) } == [["b10544215", "b11453679"]])
        #expect(ShelvedBook.duplicates(among: [first, second]).map { $0.map(\.erbID) } == [["b10544215", "b11453679"]])
        try ShelvedBook.mergeDuplicates(in: context)
        #expect(try all().first === first)
        #expect(first.rating == 5)
    }

    @Test func mergingAgainChangesNothing() throws {
        let first = record(kevade, on: .reading, at: monday)
        record(kevade, on: .read, at: day(1))
        try ShelvedBook.mergeDuplicates(in: context)
        let shelf = first.shelf
        let updated = first.updatedAt
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 0)
        #expect(try all().count == 1)
        #expect(first.shelf == shelf)
        #expect(first.updatedAt == updated)
    }

    @Test func differentBooksStayApart() throws {
        record(kevade, on: .read, at: monday)
        record(CatalogueEdition(id: 3, erbID: "b10000003", title: "Suvi", authors: "Oskar Luts"), on: .read, at: day(1))
        record(halo.work.editions[0], on: .reading, at: day(2))
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 0)
        #expect(try all().count == 3)
    }

    /// The catalogue's and Open Library's copies are matched by a looser rule when
    /// the reader shelves a book. Nothing is merged on that rule alone.
    @Test func theOtherSourcesCopyUnderAnotherTitleStaysApart() throws {
        record(CatalogueEdition(id: 7, erbID: "b10000001", title: "Halo", subtitle: "The fall of reach", authors: "Eric Nylund"), on: .read, at: monday)
        record(halo.work.editions[0], on: .reading, at: day(1))
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 0)
        #expect(try all().count == 2)
    }

    @Test func booksEnteredByHandAreNeverMerged() throws {
        ShelvedBook.add(EnteredBook(title: "Kevade", authors: "Oskar Luts"), on: .read, in: context, now: monday)
        ShelvedBook.add(EnteredBook(title: "Kevade", authors: "Oskar Luts"), on: .read, in: context, now: day(1))
        let twin = ShelvedBook(entered: EnteredBook(title: "Kevade"), shelf: .read, now: day(2))
        twin.workKey = try #require(try all().first?.workKey)
        context.insert(twin)
        #expect(try ShelvedBook.mergeDuplicates(in: context) == 0)
        #expect(try all().count == 3)
    }
}
