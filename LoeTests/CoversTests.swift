import Foundation
import Synchronization
import Testing
import UIKit
@testable import Loe

struct CoverArtTests {
    @Test func aCoverIsAskedForWithoutAPlaceholder() {
        #expect(CoverArt.id(210_551).url.absoluteString == "https://covers.openlibrary.org/b/id/210551-L.jpg?default=false")
        #expect(CoverArt.isbn("9780345451323").url.absoluteString == "https://covers.openlibrary.org/b/isbn/9780345451323-L.jpg?default=false")
        #expect(CoverArt.isbn("9780345451323").isRateLimited)
        #expect(!CoverArt.id(1).isRateLimited)
    }

    /// A cover id is not rate limited, so it wins over the ISBN.
    @Test func aBookFromOpenLibraryIsAskedForByItsCoverID() {
        #expect(CoverArt(OpenLibraryRecord(workKey: "/works/OL1W", isbn: "9780345451323", coverID: 7)) == .id(7))
        #expect(CoverArt(OpenLibraryRecord(workKey: "/works/OL1W", isbn: "9780345451323")) == .isbn("9780345451323"))
        #expect(CoverArt(OpenLibraryRecord(workKey: "/works/OL1W")) == nil)
    }

    @Test func theReadersPhotoAlwaysWins() {
        #expect(CoverChoice.of(hasPhoto: true, hasOpenLibrary: true) == .photo)
        #expect(CoverChoice.of(hasPhoto: false, hasOpenLibrary: true) == .openLibrary)
        #expect(CoverChoice.of(hasPhoto: false, hasOpenLibrary: false) == .card)
    }
}

struct CoversTests {
    private static let green = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 90)).jpegData(withCompressionQuality: 0.9) { context in
        UIColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 60, height: 90))
    }

    private let directory = URL.temporaryDirectory.appending(path: "covers-\(UUID().uuidString)")
    private let clock = Clock()
    private let asked = Asked()

    private func covers(_ status: Int, body: Data = CoversTests.green, limits: Covers.Limits = .standard) -> Covers {
        let asked = asked
        return Covers(directory: directory, limits: limits, now: clock.now) { request in
            await asked.add(request)
            return (body, status)
        }
    }

    @Test func aCoverIsKeptOnThePhone() async throws {
        let loaded = try #require(await covers(200).cover(.id(1)))
        #expect(loaded.sample != nil)
        #expect(await asked.count == 1)
        // Next launch, it comes from the phone.
        #expect(await covers(200).cover(.id(1)) == loaded)
        #expect(await asked.count == 1)
        let request = try #require(await asked.requests.first)
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains("support@helop.dev") == true)
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
    }

    @Test func aBookWithNoCoverIsNotAskedAboutAgainForAMonth() async {
        #expect(await covers(404).cover(.isbn("9789949633289")) == nil)
        #expect(await covers(404).cover(.isbn("9789949633289")) == nil)
        #expect(await asked.count == 1)
        clock.advance(by: 31 * 24 * 60 * 60)
        #expect(await covers(404).cover(.isbn("9789949633289")) == nil)
        #expect(await asked.count == 2)
    }

    @Test func aFailureIsAskedAgain() async {
        let failing = covers(503)
        #expect(await failing.cover(.id(1)) == nil)
        #expect(await failing.cover(.id(1)) == nil)
        #expect(await asked.count == 2)
    }

    /// Perhaps an outage page: skipped for the session, asked again next launch.
    @Test func somethingThatIsNotACoverIsSkippedForNow() async {
        let odd = covers(200, body: Data("not an image".utf8))
        #expect(await odd.cover(.id(1)) == nil)
        #expect(await odd.cover(.id(1)) == nil)
        #expect(await asked.count == 1)
        #expect(await covers(200, body: Data("not an image".utf8)).cover(.id(1)) == nil)
        #expect(await asked.count == 2)
    }

    @Test func memoryKeepsOnlySoManyCovers() async {
        var limits = Covers.Limits.standard
        limits.inMemory = 1
        let asked = asked
        let green = CoversTests.green
        let small = Covers(directory: nil, limits: limits, now: clock.now) { request in
            await asked.add(request)
            return (green, 200)
        }
        _ = await small.cover(.id(1))
        _ = await small.cover(.id(2))
        _ = await small.cover(.id(2))
        #expect(await asked.count == 2)
        _ = await small.cover(.id(1))
        #expect(await asked.count == 3)
    }

    /// A book scrolled past while its cover waited for a free download is not asked about.
    @Test func aCoverNobodyWantsAnyMoreIsNotSent() async throws {
        var limits = Covers.Limits.standard
        limits.concurrent = 1
        let gate = Gate()
        let asked = asked
        let green = CoversTests.green
        let one = Covers(directory: nil, limits: limits, now: clock.now) { request in
            await asked.add(request)
            if request.url?.path().contains("/id/1-") == true { await gate.wait() }
            return (green, 200)
        }
        let first = Task { await one.cover(.id(1)) }
        while await asked.count == 0 { try await Task.sleep(for: .milliseconds(5)) }
        let second = Task { await one.cover(.id(2)) }
        try await Task.sleep(for: .milliseconds(50))
        second.cancel()
        try await Task.sleep(for: .milliseconds(50))
        // Released before waiting on the second, so a broken cancel fails, not hangs.
        await gate.open()
        #expect(await first.value != nil)
        #expect(await second.value == nil)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await asked.requests.compactMap(\.url).allSatisfy { !$0.path().contains("/id/2-") })
    }

    @Test func lookupsByISBNStayUnderOpenLibrarysLimit() async {
        var limits = Covers.Limits.standard
        limits.isbnLookups = 2
        let few = covers(404, limits: limits)
        _ = await few.cover(.isbn("9780000000002"))
        _ = await few.cover(.isbn("9780000000019"))
        #expect(await few.cover(.isbn("9780000000026")) == nil)
        #expect(await asked.count == 2)
        // Cover ids are not limited.
        _ = await few.cover(.id(9))
        #expect(await asked.count == 3)
        clock.advance(by: 5 * 60 + 1)
        _ = await few.cover(.isbn("9780000000026"))
        #expect(await asked.count == 4)
    }
}

private actor Gate {
    private var opened = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiting.append($0) }
    }
    func open() {
        opened = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

private actor Asked {
    private(set) var requests: [URLRequest] = []
    var count: Int { requests.count }
    func add(_ request: URLRequest) { requests.append(request) }
}

private final class Clock: Sendable {
    private let time = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
    var now: @Sendable () -> Date { { self.time.withLock { $0 } } }
    func advance(by seconds: TimeInterval) { time.withLock { $0 += seconds } }
}

/// Which cover a catalogue book is looked up by.
struct CoverISBNTests {
    // b1 has only a PDF's ISBN, b2 a print one, b4 two printed wrong on the book, b5 is
    // an e-book with a plain ISBN, and the fixture gives b3 a hardback's.
    private func catalogue() throws -> Catalogue {
        try Catalogue(url: CatalogueFixture.make(headings: """
            INSERT INTO isbn SELECT '9789985000001', id, 'pdf' FROM edition WHERE erb_id = 'b1';
            INSERT INTO isbn SELECT '9789985000002', id, NULL FROM edition WHERE erb_id = 'b2';
            INSERT INTO isbn SELECT '9789985000003', id, 'vale' FROM edition WHERE erb_id = 'b4';
            INSERT INTO isbn SELECT '9789985000004', id, 'köites) (vale' FROM edition WHERE erb_id = 'b4';
            INSERT INTO edition (id, erb_id, title, authors, year, fiction, electronic, language) VALUES (5, 'b5', 'Tõde ja õigus', 'A. H. Tammsaare', 2021, 1, 1, 'est');
            INSERT INTO isbn VALUES ('9789985000005', 5, NULL);
            """))
    }

    @Test func onlyAPrintISBNFindsACover() async throws {
        let catalogue = try catalogue()
        #expect(try await catalogue.printISBN(of: ["b1"]) == nil)
        #expect(try await catalogue.printISBN(of: ["b4"]) == nil)
        #expect(try await catalogue.printISBN(of: ["b5"]) == nil)
        #expect(try await catalogue.printISBN(of: ["b3"]) == "9789949633289")
        #expect(try await catalogue.printISBN(of: []) == nil)
    }

    @Test func theNewestEditionWithOneIsUsed() async throws {
        let catalogue = try catalogue()
        #expect(try await catalogue.printISBN(of: ["b1", "b2", "b3"]) == "9789985000002")
        #expect(try await catalogue.printISBN(of: ["b3", "b2"]) == "9789949633289")
    }

    /// The shelves and the book's page ask the same way: the shelved edition first,
    /// then the newest with a print ISBN.
    @Test func theShelvedEditionComesFirst() async throws {
        let catalogue = try Catalogue(url: CatalogueFixture.make(headings: """
            INSERT INTO isbn SELECT '9789985000002', id, NULL FROM edition WHERE erb_id = 'b2';
            INSERT INTO isbn SELECT '9789985000006', id, NULL FROM edition WHERE erb_id = 'b1';
            """))
        let tode = CatalogueEdition(id: 2, erbID: "b2", title: "Tõde ja õigus", authors: "A. H. Tammsaare", year: 2019)
        let work = CatalogueWork(id: CatalogueWork.key(for: tode), editions: [tode])
        #expect(try await catalogue.coverISBN(for: work) == "9789985000002")
        #expect(try await catalogue.coverISBN(for: work, preferring: "b1") == "9789985000006")
    }
}
