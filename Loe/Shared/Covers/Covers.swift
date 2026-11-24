import Foundation
import ImageIO
import UIKit

/// Loads covers from Open Library and keeps them on the phone, along with the books
/// it has none for, so each is asked about once. It sends the cover id or ISBN and
/// nothing else. See docs/library.md, "Covers".
actor Covers {
    struct Loaded: Sendable, Equatable {
        let data: Data
        /// The cover's colour, for the wash behind a book's page.
        let sample: LoeTone.Sample?
    }

    struct Limits: Sendable {
        var concurrent = 4
        /// Open Library allows 100 lookups by ISBN every five minutes from one
        /// address. Loe stays under that, and skips rather than gets blocked.
        var isbnLookups = 90
        var window: TimeInterval = 5 * 60
        /// A book with no cover may get one, so it is asked about again after this.
        var missRecheck: TimeInterval = 30 * 24 * 60 * 60
        /// Covers kept in memory. The rest are read back from the phone.
        var inMemory = 200

        static let standard = Limits()
    }

    private let fetch: @Sendable (URLRequest) async throws -> (data: Data, status: Int)
    private let directory: URL?
    private let limits: Limits
    private let now: @Sendable () -> Date
    private var memory: [CoverArt: Loaded] = [:]
    private var remembered: [CoverArt] = []
    private var missing: Set<CoverArt> = []
    private var loading: [CoverArt: Task<Loaded?, Never>] = [:]
    /// Who still wants each cover being loaded. When nobody does, its download is
    /// cancelled, so a book scrolled past is not asked about.
    private var wanting: [CoverArt: Set<UUID>] = [:]
    private var isbnLookups: [Date] = []
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// `directory` keeps covers between launches. Nil keeps them in memory only.
    init(
        directory: URL?,
        limits: Limits = .standard,
        now: @escaping @Sendable () -> Date = { .now },
        fetch: @escaping @Sendable (URLRequest) async throws -> (data: Data, status: Int)
    ) {
        self.directory = directory
        self.limits = limits
        self.now = now
        self.fetch = fetch
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// The app's covers, in the caches folder, on a session that keeps no cookies,
    /// cache or credentials.
    static let live: Covers = {
        #if DEBUG
        // Journeys never touch the network: every cover id has a plain green
        // cover, and no ISBN has one.
        if NetworkStub.isOn {
            return Covers(directory: nil) { request in
                guard request.url?.path().contains("/b/id/") == true else { return (Data(), 404) }
                let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 180)).jpegData(withCompressionQuality: 0.8) { context in
                    UIColor(red: 0.2, green: 0.45, blue: 0.3, alpha: 1).setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
                }
                return (image, 200)
            }
        }
        #endif
        let session = PrivateSession.make(timeout: 15)
        let directory = URL.cachesDirectory.appending(path: "OpenLibraryCovers")
        return Covers(directory: directory) { request in
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }()

    /// The cover, or nil when Open Library has none, can't be reached, or has been
    /// asked about by ISBN too often lately.
    func cover(_ art: CoverArt) async -> Loaded? {
        if let known = memory[art] { return known }
        if missing.contains(art) { return nil }
        if let stored = stored(art) {
            keep(stored, for: art)
            return stored
        }
        if missedRecently(art) {
            missing.insert(art)
            return nil
        }
        // A download cancelled because nobody wanted it is never reused.
        let task = loading[art].flatMap { $0.isCancelled ? nil : $0 } ?? Task { await download(art) }
        loading[art] = task
        let me = UUID()
        wanting[art, default: []].insert(me)
        let loaded = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { await self.unwant(art, me) }
        }
        wanting[art]?.remove(me)
        if loading[art] == task {
            loading[art] = nil
            wanting[art] = nil
        }
        return Task.isCancelled ? nil : loaded
    }

    private func unwant(_ art: CoverArt, _ id: UUID) {
        guard wanting[art]?.remove(id) != nil, wanting[art]?.isEmpty == true else { return }
        loading[art]?.cancel()
    }

    private func download(_ art: CoverArt) async -> Loaded? {
        await acquire()
        defer { release() }
        // Cancelled while it waited for a free download: nobody wants it any more.
        guard !Task.isCancelled else { return nil }
        if art.isRateLimited {
            // Counted as it is sent, not as it is queued.
            let since = now().addingTimeInterval(-limits.window)
            isbnLookups.removeAll { $0 < since }
            guard isbnLookups.count < limits.isbnLookups else { return nil }
            isbnLookups.append(now())
        }
        guard let (data, status) = try? await fetch(URLRequest(url: art.url)) else { return nil }
        switch status {
        case 200:
            guard let loaded = Self.loaded(from: data) else {
                // Not a cover, perhaps from an outage: skipped for this session only.
                missing.insert(art)
                return nil
            }
            keep(loaded, for: art)
            if let file = file(art, "jpg") { try? data.write(to: file, options: .atomic) }
            return loaded
        case 404:
            remember(missing: art)
            return nil
        default:
            // Rate limited or a server error: not remembered, so it is asked again.
            return nil
        }
    }

    private func keep(_ loaded: Loaded, for art: CoverArt) {
        if memory.updateValue(loaded, forKey: art) == nil { remembered.append(art) }
        while remembered.count > limits.inMemory {
            memory[remembered.removeFirst()] = nil
        }
    }

    private func remember(missing art: CoverArt) {
        missing.insert(art)
        if let file = file(art, "miss") {
            try? Data().write(to: file, options: .atomic)
            try? FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: file.path)
        }
    }

    private func stored(_ art: CoverArt) -> Loaded? {
        guard let file = file(art, "jpg"), let data = try? Data(contentsOf: file) else { return nil }
        return Self.loaded(from: data)
    }

    private func missedRecently(_ art: CoverArt) -> Bool {
        guard let file = file(art, "miss"),
              let date = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
        else { return false }
        return now().timeIntervalSince(date) < limits.missRecheck
    }

    private func file(_ art: CoverArt, _ suffix: String) -> URL? {
        directory?.appending(path: "\(art.fileName).\(suffix)")
    }

    private func acquire() async {
        if active < limits.concurrent {
            active += 1
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty {
            active -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }

    /// An image worth showing, with its colour. Open Library's placeholders are tiny.
    nonisolated static func loaded(from data: Data) -> Loaded? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width >= 10, image.height >= 10
        else { return nil }
        return Loaded(data: data, sample: LoeTone.sample(from: image))
    }
}
