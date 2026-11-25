import Foundation
import ImageIO
import UIKit

/// Loads covers from Open Library and from ESTER and keeps them on the phone, along
/// with the books that have none, so each is asked about once. It sends the cover
/// id, ISBN or ESTER records and nothing else. See docs/library.md, "Covers".
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
        /// How long ESTER's covers wanted at one moment are gathered, so that a
        /// shelf asks which of its books have one in a single request.
        var gathering = Duration.milliseconds(100)

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
    /// ESTER records waiting to go in the next request, and that request's answer.
    private var esterWanted: Set<String> = []
    private var esterAnswer: Task<[String: EPIK.Record]?, Never>?
    /// The record's own summary that came with an ESTER cover.
    private var descriptions: [CoverArt: String] = [:]
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
        // cover, no ISBN has one, and ESTER has a plain blue one for one book.
        if NetworkStub.isOn {
            return Covers(directory: nil) { request in
                func plain(_ color: UIColor) -> Data {
                    UIGraphicsImageRenderer(size: CGSize(width: 120, height: 180)).jpegData(withCompressionQuality: 0.8) { context in
                        color.setFill()
                        context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
                    }
                }
                if request.url?.host() == "epik.ester.ee" {
                    return (EPIK.stubbedAnswer(to: request, cover: plain(UIColor(red: 0.2, green: 0.3, blue: 0.55, alpha: 1))), 200)
                }
                guard request.url?.path().contains("/b/id/") == true else { return (Data(), 404) }
                return (plain(UIColor(red: 0.2, green: 0.45, blue: 0.3, alpha: 1)), 200)
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

    /// The cover, or nil when there is none, its source can't be reached, or Open
    /// Library has been asked about by ISBN too often lately.
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

    /// The cover when the phone already has it, and nil otherwise. Nobody is asked,
    /// so a list shows what a book's page or a shelf found without telling anyone
    /// which books were scrolled past.
    func kept(_ art: CoverArt) -> Loaded? {
        for owner in art.keptUnder {
            if let known = memory[owner] { return known }
            if let stored = stored(owner) {
                keep(stored, for: owner)
                return stored
            }
        }
        return nil
    }

    private func unwant(_ art: CoverArt, _ id: UUID) {
        guard wanting[art]?.remove(id) != nil, wanting[art]?.isEmpty == true else { return }
        loading[art]?.cancel()
    }

    /// The record's own summary that ESTER had with a catalogue book's cover, or
    /// nil. Asks as `cover` does when nothing is known about the book yet.
    func description(for art: CoverArt) async -> String? {
        guard art.isESTERs else { return nil }
        _ = await cover(art)
        if let known = descriptions[art] { return known }
        guard let file = file(art, "txt"), let text = try? String(contentsOf: file, encoding: .utf8), !text.isEmpty else { return nil }
        descriptions[art] = text
        return text
    }

    private func download(_ art: CoverArt) async -> Loaded? {
        if case .ester(let codes, let title) = art { return await downloadFromESTER(art, codes, title) }
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
        guard let url = art.url, let (data, status) = try? await fetch(URLRequest(url: url)) else { return nil }
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

    /// A catalogue book's cover: the first of its records, in the order given, that
    /// ESTER has one for under the book's own title. A record's own summary is
    /// kept beside it.
    private func downloadFromESTER(_ art: CoverArt, _ codes: [String], _ title: String) async -> Loaded? {
        guard let records = await records(for: codes), !Task.isCancelled else { return nil }
        let known = codes.compactMap { records[$0] }
        var cover: Loaded?
        var answered = true
        var asked: Set<String> = []
        for id in known.filter(\.hasCover).compactMap(\.id).prefix(EPIK.tries) where cover == nil {
            asked.insert(id)
            guard let details = await details(of: id) else {
                answered = false
                break
            }
            // Another book's cover, filed under this record.
            guard EPIK.sameTitle(details.title, title) else { continue }
            cover = details.cover.flatMap(Self.front).flatMap(Self.loaded)
            if let description = details.description { keep(description: description, for: art) }
        }
        if descriptions[art] == nil, let id = known.first(where: \.hasDescription)?.id, !asked.contains(id),
           let details = await details(of: id), EPIK.sameTitle(details.title, title), let description = details.description {
            keep(description: description, for: art)
        }
        guard !Task.isCancelled else { return nil }
        if let cover {
            // Kept for each edition too: a shelf asks by the one edition it holds,
            // which may have no cover of its own, as an e-book's record often hasn't.
            for owner in [art] + codes.map({ CoverArt.ester([$0], title: title) }) where memory[owner] == nil {
                keep(cover, for: owner)
                missing.remove(owner)
                if let miss = file(owner, "miss") { try? FileManager.default.removeItem(at: miss) }
                if let file = file(owner, "jpg") { try? cover.data.write(to: file, options: .atomic) }
            }
        } else if answered {
            // No record has one. A failure is not remembered, so it is asked again.
            remember(missing: art)
        }
        return cover
    }

    /// What ESTER has for these records, asked together with whatever else is wanted
    /// at that moment. Nil when it can't be reached or its answer can't be read.
    private func records(for codes: [String]) async -> [String: EPIK.Record]? {
        esterWanted.formUnion(codes)
        let answer = esterAnswer ?? Task { await self.askESTER() }
        esterAnswer = answer
        return await answer.value
    }

    private func askESTER() async -> [String: EPIK.Record]? {
        try? await Task.sleep(for: limits.gathering)
        let codes = esterWanted.sorted()
        esterWanted = []
        esterAnswer = nil
        guard let request = EPIK.recordsRequest(for: codes),
              let (data, status) = try? await fetch(request), status == 200,
              let records = EPIK.records(in: data)
        else { return nil }
        return Dictionary(records.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func details(of id: String) async -> EPIK.Details? {
        await acquire()
        defer { release() }
        guard !Task.isCancelled, let request = EPIK.detailsRequest(for: id),
              let (data, status) = try? await fetch(request), status == 200
        else { return nil }
        return EPIK.details(in: data)
    }

    private func keep(description: String, for art: CoverArt) {
        descriptions[art] = description
        if let file = file(art, "txt") { try? Data(description.utf8).write(to: file, options: .atomic) }
    }

    /// The front of a cover. ESTER has some as the whole jacket, back and spine
    /// first, which is wider than it is tall: the front is its right half.
    nonisolated static func front(of data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        guard image.width > image.height else { return data }
        let half = CGRect(x: image.width - image.width / 2, y: 0, width: image.width / 2, height: image.height)
        return image.cropping(to: half).flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.9) }
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
