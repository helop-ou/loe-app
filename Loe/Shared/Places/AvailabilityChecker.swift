import Foundation

/// Asks ESTER which copies of a book's editions its libraries have, straight from
/// the phone. It sends nothing but the record numbers: no cookies, no account, and
/// answers are kept in memory only. See docs/library.md, "Availability".
actor AvailabilityChecker {
    struct Limits: Sendable {
        /// The newest editions asked about, so a book published fifty times is
        /// not fifty requests.
        var editions = 12
        var concurrent = 4
        var timeout: TimeInterval = 10
        /// How long an answer is reused, as books come and go through the day.
        var reuse: TimeInterval = 10 * 60

        static let standard = Limits()
    }

    private let fetch: @Sendable (URL) async throws -> String
    private let limits: Limits
    private let now: @Sendable () -> Date
    private var answers: [String: (at: Date, copies: [LibraryCopy])] = [:]

    init(limits: Limits = .standard, now: @escaping @Sendable () -> Date = { .now }, fetch: @escaping @Sendable (URL) async throws -> String) {
        self.limits = limits
        self.now = now
        self.fetch = fetch
    }

    /// The app's checker, on a session that keeps no cookies, cache or credentials.
    static let live: AvailabilityChecker = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = Limits.standard.timeout
        let session = URLSession(configuration: configuration)
        return AvailabilityChecker { url in
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            return String(decoding: data, as: UTF8.self)
        }
    }()

    /// Each edition's copies by ERB number, for the newest editions. Nil when no
    /// edition could be asked about, such as with no network.
    func copies(of editions: [CatalogueEdition]) async -> [String: [LibraryCopy]]? {
        let asked = Array(editions.filter { ESTERHoldings.url(erbID: $0.erbID) != nil }.prefix(limits.editions))
        guard !asked.isEmpty else { return nil }
        var result: [String: [LibraryCopy]] = [:]
        var missing: [String] = []
        for edition in asked {
            if let answer = answers[edition.erbID], now().timeIntervalSince(answer.at) < limits.reuse {
                result[edition.erbID] = answer.copies
            } else {
                missing.append(edition.erbID)
            }
        }
        let today = now()
        let fetched = await withTaskGroup(of: (String, [LibraryCopy]?).self) { group in
            var pending = missing[...]
            var found: [(String, [LibraryCopy]?)] = []
            func next() {
                guard let erbID = pending.popFirst(), let url = ESTERHoldings.url(erbID: erbID) else { return }
                let fetch = self.fetch
                group.addTask { (erbID, try? ESTERHoldings.copies(in: await fetch(url), today: today)) }
            }
            for _ in 0..<limits.concurrent { next() }
            for await answer in group {
                found.append(answer)
                next()
            }
            return found
        }
        for (erbID, copies) in fetched {
            guard let copies else { continue }
            answers[erbID] = (today, copies)
            result[erbID] = copies
        }
        return result.isEmpty ? nil : result
    }
}
