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

    /// Open Library asks apps to name themselves and give a contact.
    static let userAgent = "Loe/\(LoeProject.version) (\(LoeProject.repository.absoluteString); \(LoeProject.contact))"

    private let fetch: @Sendable (URLRequest) async throws -> Data
    private var answers: [String: [OpenLibraryBook]] = [:]

    init(fetch: @escaping @Sendable (URLRequest) async throws -> Data) {
        self.fetch = fetch
    }

    /// The app's client, on a session that keeps no cookies, cache or credentials.
    static let live: OpenLibrary = {
        #if DEBUG
        // Journeys never touch the network: a search with "halo" in it finds Halo,
        // one with "offline" fails as with no network, and any other finds nothing.
        if UserDefaults.standard.bool(forKey: "openLibraryStub") {
            return OpenLibrary { request in
                let query = request.url?.query()?.lowercased() ?? ""
                if query.contains("offline") { throw URLError(.notConnectedToInternet) }
                return Data((query.contains("halo") ? stubAnswer : #"{"docs": []}"#).utf8)
            }
        }
        #endif
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        return OpenLibrary { request in
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            return data
        }
    }()

    /// Whether this is worth asking Open Library about: a few characters, not an
    /// ISBN, which is a barcode's job.
    static func asksAbout(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && CatalogueQuery.isbn13(trimmed) == nil
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
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        // Otherwise the system sends the reader's own preferred languages.
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        return request
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
nonisolated private let stubAnswer = """
{"docs": [{"key": "/works/OL18626W", "title": "Halo", "author_name": ["Eric S. Nylund"], "first_publish_year": 2001,
  "number_of_pages_median": 339, "cover_i": 210551,
  "editions": {"docs": [{"title": "Halo", "subtitle": "The Fall of Reach", "language": ["eng"], "isbn": ["9780345451323", "0345451325"]}]}}]}
"""
#endif
