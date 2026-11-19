import Foundation
import Testing
@testable import Loe

/// Answers saved from Open Library's search in November 2026, with the app's fields.
struct OpenLibraryTests {
    private static let fixtures = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures")

    private static func books(_ name: String) throws -> [OpenLibraryBook] {
        let data = try Data(contentsOf: fixtures.appending(path: "openlibrary-\(name).json"))
        return OpenLibraryBook.books(in: try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data))
    }

    @Test func aWorkWithNoSubtitleTakesItsEditions() throws {
        let books = try Self.books("halo-fall-of-reach")
        let halo = try #require(books.first)
        #expect(halo.title == "Halo: The fall of reach")
        #expect(halo.authors == ["Eric S. Nylund"])
        #expect(halo.record.workKey.hasPrefix("/works/"))
        #expect(halo.record.isbn == "9780765367297")
        #expect(halo.record.coverID == 7_995_273)
        #expect(halo.language == "eng")
    }

    /// Open Library has the book as several works, with and without a middle initial.
    @Test func oneBookIsListedOnce() throws {
        let books = try Self.books("halo-fall-of-reach")
        let titles = books.map { CatalogueQuery.folded($0.title) }
        #expect(titles.filter { $0 == "halo the fall of reach" }.count == 1)
        #expect(books.count < 5)
    }

    @Test func aTranslatedBookShowsItsEnglishTitle() throws {
        let wish = try #require(Self.books("last-wish").first)
        #expect(wish.title == "The Last Wish")
        #expect(wish.authors == ["Andrzej Sapkowski"])
    }

    @Test func theWorksOwnTitleWinsOverASloppyEdition() throws {
        // The edition is "Fourth WIng".
        let wing = try #require(Self.books("fourth-wing").first)
        #expect(wing.title == "Fourth Wing")
        #expect(wing.pages == 522)
        #expect(wing.year == 2023)
    }

    @Test func titlesThatOverlapKeepTheWorks() {
        let title = OpenLibraryBook.displayTitle(
            work: ("Slaughterhouse-Five", nil),
            edition: ("Kurt Vonnegut's Slaughterhouse Five (Monarch Notes)", nil)
        )
        #expect(title == "Slaughterhouse-Five")
        #expect(OpenLibraryBook.displayTitle(work: ("Piranesi", nil), edition: nil) == "Piranesi")
        // A publisher's blurb in the subtitle stays out.
        let onyx = OpenLibraryBook.displayTitle(
            work: ("Onyx Storm", nil),
            edition: ("Onyx Storm", "Discover the Follow-Up to the Global Phenomenons, Fourth Wing and Iron Flame!")
        )
        #expect(onyx == "Onyx Storm")
    }

    @Test func aBrokenAnswerLosesOnlyTheBrokenPart() throws {
        let json = #"{"docs": [42, {"title": "No key"}, {"key": "/authors/OL1A", "title": "An author"}, {"key": "/works/OL1W", "title": " Piranesi ", "author_name": ["Susanna Clarke"], "cover_i": "big"}]}"#
        let books = OpenLibraryBook.books(in: try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: Data(json.utf8)))
        #expect(books.map(\.title) == ["Piranesi"])
        #expect(books.first?.record.coverID == nil)
        let odd = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: Data(#"{"docs": "none"}"#.utf8))
        #expect(OpenLibraryBook.books(in: odd).isEmpty)
    }

    @Test func booksTheCatalogueShowsAreLeftOut() {
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "The czar's madman", authors: "Jaan Kross")
        let catalogue = [CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross])]
        let online = [
            OpenLibraryBook(record: .init(workKey: "/works/OL1W"), title: "The Czar's Madman", authors: ["Jaan Kross"]),
            OpenLibraryBook(record: .init(workKey: "/works/OL2W"), title: "Treading Air", authors: ["Jaan Kross"]),
        ]
        #expect(OpenLibraryBook.unseen(online, besides: catalogue).map(\.title) == ["Treading Air"])
    }

    /// The catalogue keeps a subtitle apart, Open Library puts it in the title, and
    /// either may drop a leading article or a middle initial.
    @Test func theSameBookIsSpottedHoweverItIsWritten() {
        let halo = CatalogueEdition(id: 1, erbID: "b10000001", title: "Halo", subtitle: "The fall of reach", authors: "Eric Nylund")
        let kross = CatalogueEdition(id: 2, erbID: "b10544215", title: "The czar's madman", authors: "Jaan Kross")
        let catalogue = [halo, kross].map { CatalogueWork(id: CatalogueWork.key(for: $0), editions: [$0]) }
        let online = [
            OpenLibraryBook(record: .init(workKey: "/works/OL1W"), title: "Halo: The Fall of Reach", authors: ["Eric S. Nylund"]),
            OpenLibraryBook(record: .init(workKey: "/works/OL2W"), title: "Czar S Madman", authors: ["Jaan Kross"]),
            OpenLibraryBook(record: .init(workKey: "/works/OL3W"), title: "Halo: First Strike", authors: ["Eric S. Nylund"]),
        ]
        #expect(OpenLibraryBook.unseen(online, besides: catalogue).map(\.title) == ["Halo: First Strike"])
    }

    @Test func theRequestAsksForEnglishEditionsAndNamesTheApp() throws {
        let request = try #require(OpenLibrary.searchRequest(for: "  halo  "))
        let items = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        #expect(request.url?.host() == "openlibrary.org")
        #expect(request.url?.scheme == "https")
        #expect(value("q") == "halo")
        #expect(value("lang") == "en")
        #expect(value("fields")?.contains("editions.isbn") == true)
        // The system would otherwise send the reader's own languages.
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
        let agent = try #require(request.value(forHTTPHeaderField: "User-Agent"))
        #expect(agent.contains("support@helop.dev"))
        #expect(agent.contains("https://github.com/helop-ou/loe-app"))
    }

    @Test func onlyRealSearchesAreSent() {
        #expect(!OpenLibrary.asksAbout("ha"))
        #expect(!OpenLibrary.asksAbout("978-0-306-40615-7"))
        #expect(OpenLibrary.asksAbout("1984"))
        #expect(OpenLibrary.asksAbout("halo"))
    }

    @Test func nothingIsSentUntilTypingPauses() async throws {
        let calls = Calls()
        let client = OpenLibrary { _ in
            await calls.add()
            return Data(#"{"docs": []}"#.utf8)
        }
        let typedOn = Task { try await client.search(afterPause: .seconds(5), for: "halo") }
        typedOn.cancel()
        #expect(try await typedOn.value == nil)
        #expect(await calls.count == 0)

        #expect(try await client.search(afterPause: .milliseconds(1), for: "halo") == [])
        #expect(await calls.count == 1)
        // The same search again is answered from memory, and shown without waiting.
        #expect(await client.known(" Halo ") == [])
        #expect(try await client.search(afterPause: .milliseconds(1), for: "Halo") == [])
        #expect(await calls.count == 1)
        // A search that differs in more than case and spacing is asked anew.
        #expect(await client.known("C# in depth") == nil)
        _ = try await client.search("C in depth")
        #expect(await client.known("C# in depth") == nil)
    }

    @Test func aFailedAnswerIsAnError() async {
        let client = OpenLibrary { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: URLError.self) { try await client.search("halo") }
    }
}

private actor Calls {
    private(set) var count = 0
    func add() { count += 1 }
}
