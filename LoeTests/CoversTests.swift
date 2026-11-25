import Foundation
import Synchronization
import Testing
import UIKit
@testable import Loe

struct CoverArtTests {
    @Test func aCoverIsAskedForWithoutAPlaceholder() {
        #expect(CoverArt.id(210_551).url?.absoluteString == "https://covers.openlibrary.org/b/id/210551-L.jpg?default=false")
        #expect(CoverArt.isbn("9780345451323").url?.absoluteString == "https://covers.openlibrary.org/b/isbn/9780345451323-L.jpg?default=false")
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
        #expect(CoverChoice.of(hasPhoto: true, hasFound: true) == .photo)
        #expect(CoverChoice.of(hasPhoto: false, hasFound: true) == .found)
        #expect(CoverChoice.of(hasPhoto: false, hasFound: false) == .card)
    }

    /// The record is the edition's number without its check digit, each once, the
    /// one to prefer first, and no more than a page asks about.
    @Test func aCatalogueBookIsAskedForByItsEditionsRecords() {
        #expect(CoverArt(erbIDs: ["b54543241", "b5469104x", "b54543241"], title: "Keisri hull") == .ester(["b5454324", "b5469104"], title: "Keisri hull"))
        #expect(CoverArt(erbIDs: ["", "hand:1", "b1"], title: "Keisri hull") == nil)
        let many = (10...40).map { "b10000\($0)1" }
        #expect(CoverArt(erbIDs: many, title: "Keisri hull") == .ester((10...21).map { "b10000\($0)" }, title: "Keisri hull"))
        #expect(CoverArt.ester(["b5454324"], title: "Keisri hull").url == nil)
        #expect(CoverArt.ester(["b5454324"], title: "Keisri hull").isESTERs)
        #expect(!CoverArt.id(1).isESTERs)
        #expect(CoverArt.ester(["b5454324", "b5469104"], title: "Keisri hull").fileName == "ester-b5454324-b5469104")
        #expect(CoverArt.ester(["b5454324"], title: "Keisri hull").fileName == "ester-b5454324")
    }

    /// A page keeps the cover it found under its twelve newest editions together
    /// and under each alone, and a shelf keeps one under the edition it holds.
    @Test func aBooksCoverMayBeKeptUnderAnyOfItsEditions() {
        let many = (10...24).map { "b10000\($0)" }
        let whole = CoverArt.ester(Array(many.prefix(12)), title: "Keisri hull")
        #expect(CoverArt.ester(many, title: "Keisri hull").keptUnder == [whole] + many.map { .ester([$0], title: "Keisri hull") })
        #expect(CoverArt.ester(["b5454324"], title: "Keisri hull").keptUnder == [.ester(["b5454324"], title: "Keisri hull")])
        #expect(CoverArt.id(7).keptUnder == [.id(7)])
        #expect(CoverArt.isbn("9780345451323").keptUnder == [.isbn("9780345451323")])
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
    }

    /// A list shows what the phone has, and asks nobody about the rest.
    @Test func aKeptCoverIsGivenWithoutAsking() async throws {
        #expect(await covers(200).kept(.id(1)) == nil)
        #expect(await covers(200).kept(.isbn("9780345451323")) == nil)
        #expect(await asked.count == 0)
        let asking = covers(200)
        let loaded = try #require(await asking.cover(.id(1)))
        #expect(await asking.kept(.id(1)) == loaded)
        // Next launch, it comes from the phone.
        #expect(await covers(200).kept(.id(1)) == loaded)
        #expect(await asked.count == 1)
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

/// Covers and summaries from ESTER, against a stand-in for EPIK that has what each
/// test says it has.
struct ESTERCoversTests {
    private struct Has: Sendable {
        var cover: Data?
        var description: String?
        /// The title EPIK has the record under. Every test asks about „Keisri hull“.
        var title = "Keisri hull : romaan"
    }

    private static let blue = EPIKTests.picture(width: 160, height: 240)

    private let directory = URL.temporaryDirectory.appending(path: "covers-\(UUID().uuidString)")
    private let clock = Clock()
    private let asked = Asked()

    private func covers(_ has: [String: Has], status: Int = 200, detailsStatus: Int = 200) -> Covers {
        let asked = asked
        return Covers(directory: directory, now: clock.now) { request in
            await asked.add(request)
            guard status == 200 else { return (Data("<html>Service unavailable</html>".utf8), status) }
            if request.httpMethod != "POST", detailsStatus != 200 { return (Data(), detailsStatus) }
            if request.httpMethod == "POST" {
                let codes = try JSONDecoder().decode([String].self, from: request.httpBody ?? Data())
                let items = codes.map { code -> [String: Any] in
                    let known = has[code]
                    return [
                        "code": code, "idUuid": known == nil ? NSNull() : "0000-" + code.dropFirst(),
                        "imageData": known?.cover == nil ? NSNull() : "thumbnail",
                        "isContentPresent": false, "isContentDescriptionPresent": known?.description != nil,
                    ]
                }
                return (try JSONSerialization.data(withJSONObject: items), 200)
            }
            let id = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value ?? ""
            let known = has["b" + id.dropFirst(5)]
            return (EPIKTests.details(cover: known?.cover, description: known?.description, title: known?.title ?? ""), 200)
        }
    }

    private var posts: [[String]] {
        get async {
            await asked.requests.filter { $0.httpMethod == "POST" }.map { (try? JSONDecoder().decode([String].self, from: $0.httpBody ?? Data())) ?? [] }
        }
    }

    private var detailsAsked: [String] {
        get async {
            await asked.requests.filter { $0.httpMethod != "POST" }.compactMap { $0.url?.query() }
        }
    }

    @Test func theFirstEditionWithACoverGivesIt() async throws {
        let has = ["b2000002": Has(cover: Self.blue), "b1000001": Has(cover: EPIKTests.picture(width: 100, height: 150))]
        let loaded = try #require(await covers(has).cover(.ester(["b3000003", "b2000002", "b1000001"], title: "Keisri hull")))
        #expect(loaded.data == Self.blue)
        #expect(loaded.sample != nil)
        #expect(await posts == [["b1000001", "b2000002", "b3000003"]])
        #expect(await detailsAsked == ["idUuid=0000-2000002"])
    }

    @Test func aCoverAndTheRecordsSummaryAreKeptOnThePhone() async throws {
        let has = ["b1000001": Has(cover: Self.blue, description: "Kroonik kirjutab üles oma õemehe loo.")]
        let art = CoverArt.ester(["b1000001"], title: "Keisri hull")
        let first = covers(has)
        let loaded = try #require(await first.cover(art))
        #expect(await first.description(for: art) == "Kroonik kirjutab üles oma õemehe loo.")
        #expect(await asked.count == 2)
        // Next launch, both come from the phone.
        let next = covers(has)
        #expect(await next.description(for: art) == "Kroonik kirjutab üles oma õemehe loo.")
        #expect(await next.cover(art) == loaded)
        #expect(await asked.count == 2)
    }

    @Test func coversWantedAtTheSameMomentGoInOneRequest() async {
        let has = ["b1000001": Has(cover: Self.blue), "b2000002": Has(cover: Self.blue), "b3000003": Has()]
        let covers = covers(has)
        async let first = covers.cover(.ester(["b1000001"], title: "Keisri hull"))
        async let second = covers.cover(.ester(["b2000002"], title: "Keisri hull"))
        async let third = covers.cover(.ester(["b3000003"], title: "Keisri hull"))
        #expect(await first != nil)
        #expect(await second != nil)
        #expect(await third == nil)
        #expect(await posts == [["b1000001", "b2000002", "b3000003"]])
        #expect(await detailsAsked.sorted() == ["idUuid=0000-1000001", "idUuid=0000-2000002"])
    }

    /// EPIK files some records under another book, and gives that book's cover.
    @Test func aCoverFiledUnderAnotherBookIsPassedOver() async throws {
        let wrong = Has(cover: EPIKTests.picture(width: 100, height: 150), description: "Teise raamatu lugu.", title: "Betti, kibuvits õitseb")
        // The newest edition has another book's cover, and an older one has its own.
        let covers = covers(["b2000002": wrong, "b1000001": Has(cover: Self.blue)])
        let art = CoverArt.ester(["b2000002", "b1000001"], title: "Keisri hull")
        let loaded = try #require(await covers.cover(art))
        #expect(loaded.data == Self.blue)
        #expect(await covers.description(for: art) == nil)
        #expect(await detailsAsked == ["idUuid=0000-2000002", "idUuid=0000-1000001"])
        // With no edition of its own to fall back on, the book shows its card.
        #expect(await self.covers(["b3000003": wrong]).cover(.ester(["b3000003"], title: "Keisri hull")) == nil)
    }

    /// A shelf holds one edition, often an e-book with no cover of its own.
    @Test func theShelfShowsTheCoverTheBooksPageFound() async throws {
        let has = ["b1000001": Has(cover: Self.blue)]
        let shelved = CoverArt.ester(["b2000002"], title: "Keisri hull")
        // Asked by its own edition first, the shelf finds none.
        #expect(await covers(has).cover(shelved) == nil)
        let page = covers(has)
        let found = try #require(await page.cover(.ester(["b2000002", "b1000001"], title: "Keisri hull")))
        let before = await asked.count
        #expect(await page.cover(shelved) == found)
        // And so does the next launch, with nothing more asked.
        #expect(await covers(has).cover(shelved) == found)
        #expect(await asked.count == before)
    }

    /// A list has a book's editions as its search found them, which need not be
    /// the ones its page asked about, or in that order.
    @Test func aListShowsTheCoverTheBooksPageFound() async throws {
        let has = ["b1000001": Has(cover: Self.blue)]
        let listed = CoverArt.ester(["b3000003", "b1000001"], title: "Keisri hull")
        #expect(await covers(has).kept(listed) == nil)
        #expect(await asked.count == 0)
        let page = covers(has)
        let found = try #require(await page.cover(.ester(["b2000002", "b1000001"], title: "Keisri hull")))
        let before = await asked.count
        #expect(await page.kept(listed) == found)
        // And so does the next launch, with nobody asked.
        #expect(await covers(has).kept(listed) == found)
        #expect(await asked.count == before)
    }

    /// A shelf keeps a cover under the edition it holds, which a book with many
    /// editions lists after the twelve its page asks about.
    @Test func aListShowsTheCoverAShelfFound() async throws {
        let has = ["b1000024": Has(cover: Self.blue)]
        let found = try #require(await covers(has).cover(.ester(["b1000024"], title: "Keisri hull")))
        let before = await asked.count
        let listed = CoverArt.ester((10...24).map { "b10000\($0)" }, title: "Keisri hull")
        #expect(await covers(has).kept(listed) == found)
        #expect(await asked.count == before)
    }

    @Test func aBookWithNoCoverIsNotAskedAboutAgainForAMonth() async {
        let art = CoverArt.ester(["b1000001"], title: "Keisri hull")
        #expect(await covers([:]).cover(art) == nil)
        #expect(await covers([:]).cover(art) == nil)
        #expect(await asked.count == 1)
        clock.advance(by: 31 * 24 * 60 * 60)
        #expect(await covers([:]).cover(art) == nil)
        #expect(await asked.count == 2)
    }

    @Test func anOutageIsNotTakenForABookWithNoCover() async {
        let art = CoverArt.ester(["b1000001"], title: "Keisri hull")
        #expect(await covers([:], status: 503).cover(art) == nil)
        #expect(await covers(["b1000001": Has(cover: Self.blue)]).cover(art) != nil)
        #expect(await posts.count == 2)
    }

    @Test func aCoverThatCouldNotBeFetchedIsAskedForAgain() async {
        let has = ["b1000001": Has(cover: Self.blue)]
        let art = CoverArt.ester(["b1000001"], title: "Keisri hull")
        #expect(await covers(has, detailsStatus: 500).cover(art) == nil)
        #expect(await covers(has).cover(art) != nil)
        #expect(await posts.count == 2)
    }

    @Test func aWholeJacketIsCutToItsFront() async throws {
        // Back and spine first, in red, and the front in blue.
        let jacket = EPIKTests.picture(width: 340, height: 240, left: .red, right: .blue)
        let loaded = try #require(await covers(["b1000001": Has(cover: jacket)]).cover(.ester(["b1000001"], title: "Keisri hull")))
        let image = try #require(UIImage(data: loaded.data)?.cgImage)
        #expect(image.width == 170)
        #expect(image.height == 240)
        // Blue's hue is two thirds of the way round, and red's is at the start.
        let sample = try #require(loaded.sample)
        #expect((0.55...0.75).contains(sample.hue))
        // An ordinary cover is kept as it came.
        #expect(Covers.front(of: Self.blue) == Self.blue)
    }

    @Test func aSummaryOnAnotherEditionIsFoundToo() async {
        let has = ["b2000002": Has(cover: Self.blue), "b1000001": Has(description: "Kroonik kirjutab üles oma õemehe loo.")]
        let covers = covers(has)
        let art = CoverArt.ester(["b2000002", "b1000001"], title: "Keisri hull")
        #expect(await covers.cover(art) != nil)
        #expect(await covers.description(for: art) == "Kroonik kirjutab üles oma õemehe loo.")
        #expect(await detailsAsked == ["idUuid=0000-2000002", "idUuid=0000-1000001"])
    }

    @Test func aSummaryShowsForABookWithNoCover() async {
        let has = ["b1000001": Has(description: "Kroonik kirjutab üles oma õemehe loo.")]
        let art = CoverArt.ester(["b1000001"], title: "Keisri hull")
        let first = covers(has)
        #expect(await first.description(for: art) == "Kroonik kirjutab üles oma õemehe loo.")
        #expect(await first.cover(art) == nil)
        #expect(await asked.count == 2)
        // Next launch it is read from the phone, and the missing cover is not asked for.
        #expect(await covers(has).description(for: art) == "Kroonik kirjutab üles oma õemehe loo.")
        #expect(await asked.count == 2)
    }

    @Test func aCoverFromOpenLibraryHasNoSummary() async {
        #expect(await covers([:]).description(for: .id(7)) == nil)
        #expect(await asked.count == 0)
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
