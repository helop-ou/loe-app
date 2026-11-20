import Foundation

/// Searches Open Library for books the catalogue doesn't have. It sends what the
/// reader searched for and nothing else: no cookies, no account, and answers are
/// kept in memory only. See docs/catalogue.md, "Books from abroad".
actor OpenLibrary {
    /// How long typing has to pause before Open Library is asked. Open Library
    /// allows three requests a second from an app that names itself, and a pause
    /// this long keeps a reader well under that.
    static let pause = Duration.milliseconds(600)

    static let fields = [
        "key", "title", "subtitle", "author_name", "first_publish_year", "number_of_pages_median", "cover_i",
        "editions", "editions.title", "editions.subtitle", "editions.language", "editions.isbn", "editions.cover_i",
    ].joined(separator: ",")

    private let fetch: @Sendable (URLRequest) async throws -> Data
    private var answers: [String: [OpenLibraryBook]] = [:]

    init(fetch: @escaping @Sendable (URLRequest) async throws -> Data) {
        self.fetch = fetch
    }

    /// The app's client, on a session that keeps no cookies, cache or credentials.
    static let live: OpenLibrary = {
        #if DEBUG
        // Journeys never touch the network: a search with "halo" or Halo's ISBN in it
        // finds Halo, one with "hail mary" finds Project Hail Mary, which the
        // catalogue has in Estonian, one with "offline" fails as with no network,
        // and any other finds nothing.
        if UserDefaults.standard.bool(forKey: "openLibraryStub") {
            return OpenLibrary { request in
                let query = request.url?.query(percentEncoded: false)?.lowercased() ?? ""
                if query.contains("offline") { throw URLError(.notConnectedToInternet) }
                let halo = query.contains("halo") || query.contains("isbn:9780345451323")
                let docs = halo ? stubHalo : query.contains("hail mary") ? stubHailMary : ""
                return Data(#"{"docs": [\#(docs)]}"#.utf8)
            }
        }
        #endif
        let session = PrivateSession.make(timeout: 10)
        return OpenLibrary { request in
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            return data
        }
    }()

    /// What Open Library is asked about a search, or nil when it isn't asked. An
    /// ISBN is the catalogue's to answer first, so Open Library hears of one only
    /// when the catalogue doesn't have it. Any other text needs a few characters.
    static func question(for text: String, catalogueFound: Bool) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let isbn = CatalogueQuery.isbn13(trimmed) {
            return catalogueFound ? nil : "isbn:\(isbn)"
        }
        return trimmed.count >= 3 ? trimmed : nil
    }

    static func searchRequest(for text: String) -> URLRequest? {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text.trimmingCharacters(in: .whitespacesAndNewlines)),
            // English editions, and the edition inside each work that matched.
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "fields", value: fields),
        ]
        guard let url = components.url else { return nil }
        return URLRequest(url: url)
    }

    /// Asks once typing has paused. Nil when the reader typed on, which cancels the
    /// waiting task before anything is sent.
    func search(afterPause pause: Duration = OpenLibrary.pause, for text: String) async throws -> [OpenLibraryBook]? {
        try? await Task.sleep(for: pause)
        guard !Task.isCancelled else { return nil }
        return try await search(text)
    }

    /// The answer to a search already made this session, without waiting.
    func known(_ text: String) -> [OpenLibraryBook]? {
        answers[Self.memoryKey(text)]
    }

    private static func memoryKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func search(_ text: String) async throws -> [OpenLibraryBook] {
        let key = Self.memoryKey(text)
        if let known = answers[key] { return known }
        guard let request = Self.searchRequest(for: text) else { return [] }
        let data = try await fetch(request)
        let books = OpenLibraryBook.books(in: try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data))
        answers[key] = books
        return books
    }
}

#if DEBUG
nonisolated private let stubHalo = """
{"key": "/works/OL18626W", "title": "Halo", "author_name": ["Eric S. Nylund"], "first_publish_year": 2001,
  "number_of_pages_median": 339, "cover_i": 210551,
  "editions": {"docs": [{"title": "Halo", "subtitle": "The Fall of Reach", "language": ["eng"], "isbn": ["9780345451323", "0345451325"]}]}}
"""

nonisolated private let stubHailMary = """
{"key": "/works/OL21745884W", "title": "Project Hail Mary", "author_name": ["Andy Weir"], "first_publish_year": 2021,
  "number_of_pages_median": 496, "cover_i": 11200092,
  "editions": {"docs": [{"title": "Project Hail Mary", "language": ["eng"], "isbn": ["9780593135204", "0593135202"]}]}}
"""
#endif
