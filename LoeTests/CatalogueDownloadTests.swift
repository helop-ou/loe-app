import Foundation
import Synchronization
import Testing
@testable import Loe

/// Serves canned responses to a URLSession, and records what was asked for.
nonisolated final class StubServer: URLProtocol {
    private static let responses = Mutex<[URL: (status: Int, body: Data)]>([:])
    private static let failures = Mutex<[URL: URLError.Code]>([:])
    private static let requested = Mutex<[URLRequest]>([])

    static func serve(_ url: URL, status: Int = 200, body: Data) {
        failures.withLock { $0[url] = nil }
        responses.withLock { $0[url] = (status, body) }
    }

    /// Fails every request for `url` as a network that can't be used does.
    static func fail(_ url: URL, with code: URLError.Code) {
        failures.withLock { $0[url] = code }
    }

    static func wasRequested(_ url: URL) -> Bool {
        !requests(for: url).isEmpty
    }

    /// Every request for `url`, in the order they were made.
    static func requests(for url: URL) -> [URLRequest] {
        requested.withLock { $0.filter { $0.url == url } }
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubServer.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        Self.requested.withLock { $0.append(request) }
        if let code = Self.failures.withLock({ $0[url] }) {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        let (status, body) = Self.responses.withLock { $0[url] } ?? (404, Data())
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": String(body.count)]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Each test gets its own host, folder and defaults, so they can run side by side.
struct DownloadScene {
    let host = URL(string: "https://\(UUID().uuidString.lowercased()).test")!
    let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
    let defaults = UserDefaults(suiteName: UUID().uuidString)!

    var manifestURL: URL { host.appending(path: "manifest.json") }
    var catalogueURL: URL { folder.appending(path: "Catalogue/catalogue.sqlite") }
    var downloader: CatalogueDownloader { CatalogueDownloader(manifestURL: manifestURL, session: StubServer.session) }

    /// Serves a catalogue's xz file the way a release does, and gives what a manifest
    /// says of it.
    func release(
        _ catalogue: URL,
        version: String,
        schema: Int = Catalogue.schemaVersion,
        sha256: String? = nil,
        editions: Int? = nil
    ) throws -> (file: URL, entry: String) {
        let file = host.appending(path: "catalogue-\(version).sqlite.xz")
        let compressed = try CatalogueFixture.xz(of: catalogue)
        StubServer.serve(file, body: compressed)
        let checksum = try sha256 ?? {
            let temporary = URL.temporaryDirectory.appending(path: UUID().uuidString)
            try compressed.write(to: temporary)
            return try CatalogueDownloader.sha256(of: temporary)
        }()
        let entry = """
            "version": "\(version)", "schema_version": \(schema), "url": "\(file.absoluteString)",
            "sha256": "\(checksum)", "size": \(compressed.count)\(editions.map { #", "editions": \#($0)"# } ?? "")
            """
        return (file, entry)
    }

    /// Publishes a catalogue as the manifest's top level, with the catalogues of
    /// other schemas listed under it, and what the manifest says about asking ESTER
    /// when it says anything.
    @discardableResult
    func publish(
        _ catalogue: URL,
        version: String,
        schema: Int = Catalogue.schemaVersion,
        sha256: String? = nil,
        editions: Int? = nil,
        listing others: [String] = [],
        asksESTER: String? = nil
    ) throws -> URL {
        let (file, entry) = try release(catalogue, version: version, schema: schema, sha256: sha256, editions: editions)
        let list = others.isEmpty ? "" : #", "catalogues": [\#(others.map { "{\($0)}" }.joined(separator: ", "))]"#
        let ester = asksESTER.map { #", "asks_ester": \#($0)"# } ?? ""
        StubServer.serve(manifestURL, body: Data("{\(entry)\(list)\(ester)}".utf8))
        return file
    }

    func store() -> CatalogueStore {
        CatalogueStore(url: catalogueURL, downloader: downloader, defaults: defaults)
    }

    func install(_ catalogue: URL, version: String) throws {
        try FileManager.default.createDirectory(at: catalogueURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: catalogue, to: catalogueURL)
        defaults.set(version, forKey: "catalogueVersion")
    }
}

struct CatalogueDownloadTests {
    private static let otherBooks = "(1, 'b9', 'Keisri hull', 'Jaan Kross', 1978, 1, 0, NULL, 'est', NULL, NULL)"

    @Test func downloadsChecksAndOpensTheCatalogue() async throws {
        let scene = DownloadScene()
        try scene.publish(CatalogueFixture.make(), version: "2026-11")
        let store = scene.store()
        guard case .missing = store.state else { Issue.record("expected missing"); return }

        await store.downloadCatalogue()

        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("tammsaare").map(\.title) == ["Tõde ja õigus"])
        #expect(store.download == nil)
        #expect(store.installedVersion == "2026-11")
        let values = try scene.catalogueURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func aFailedDownloadSaysSo() async {
        let scene = DownloadScene()
        let store = scene.store()
        await store.downloadCatalogue()
        #expect(store.download == .failed)
        guard case .missing = store.state else { Issue.record("expected missing"); return }
    }

    @Test func aBadChecksumKeepsTheCatalogueAlreadyThere() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        try scene.publish(CatalogueFixture.make(books: Self.otherBooks), version: "2026-11", sha256: String(repeating: "0", count: 64))
        let published = try #require(try await scene.downloader.manifest().catalogue(forSchema: Catalogue.schemaVersion))

        await #expect(throws: CatalogueDownloader.Failure.checksumMismatch) {
            try await scene.downloader.install(published, at: scene.catalogueURL)
        }
        let works = try await Catalogue(url: scene.catalogueURL).search("tammsaare")
        #expect(works.map(\.title) == ["Tõde ja õigus"])
    }

    @Test func aFileThatIsNotACatalogueKeepsTheOneAlreadyThere() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        let garbage = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("not a catalogue".utf8).write(to: garbage)
        try scene.publish(garbage, version: "2026-11")
        let published = try #require(try await scene.downloader.manifest().catalogue(forSchema: Catalogue.schemaVersion))

        await #expect(throws: (any Error).self) {
            try await scene.downloader.install(published, at: scene.catalogueURL)
        }
        let works = try await Catalogue(url: scene.catalogueURL).search("tammsaare")
        #expect(works.map(\.title) == ["Tõde ja õigus"])
    }

    @Test func aCatalogueForANewerAppIsNotDownloaded() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2027-01", schema: Catalogue.schemaVersion + 1)
        let published = try #require(try await scene.downloader.manifest().catalogue(forSchema: Catalogue.schemaVersion + 1))

        await #expect(throws: CatalogueDownloader.Failure.unsupportedSchema(Catalogue.schemaVersion + 1)) {
            try await scene.downloader.install(published, at: scene.catalogueURL)
        }
        #expect(!StubServer.wasRequested(file))
    }

    // A catalogue of a newer schema is listed beside the one this build reads, which
    // stays published. See docs/catalogue.md, "Download and updates".
    @Test func aBuildStillInstallsItsOwnCatalogueOnceANewerSchemaIsPublished() async throws {
        let scene = DownloadScene()
        let newer = try scene.release(CatalogueFixture.make(books: Self.otherBooks), version: "2027-01", schema: Catalogue.schemaVersion + 1)
        try scene.publish(CatalogueFixture.make(), version: "2026-11", listing: [newer.entry])
        let store = scene.store()

        await store.downloadCatalogue()

        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("tammsaare").map(\.title) == ["Tõde ja õigus"])
        #expect(store.installedVersion == "2026-11")
        #expect(!StubServer.wasRequested(newer.file))
    }

    @Test func aBuildOfALaterSchemaInstallsTheCatalogueListedForIt() async throws {
        let scene = DownloadScene()
        let own = try scene.release(CatalogueFixture.make(books: Self.otherBooks), version: "2027-01")
        let older = try scene.publish(
            CatalogueFixture.make(), version: "2026-11", schema: Catalogue.schemaVersion - 1, listing: [own.entry]
        )
        let store = scene.store()

        await store.downloadCatalogue()

        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("kross").map(\.title) == ["Keisri hull"])
        #expect(store.installedVersion == "2027-01")
        #expect(!StubServer.wasRequested(older))
    }

    @Test func theFirstDownloadSaysWhenEveryCatalogueNeedsANewerLoe() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2027-01", schema: Catalogue.schemaVersion + 1)
        let store = scene.store()

        await store.downloadCatalogue()

        #expect(store.download == .needsNewerLoe)
        guard case .missing = store.state else { Issue.record("expected missing"); return }
        #expect(!StubServer.wasRequested(file))
    }

    @Test func aManifestWithOnlyOlderCataloguesIsADownloadThatFailed() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11", schema: Catalogue.schemaVersion - 1)
        let store = scene.store()

        await store.downloadCatalogue()

        #expect(store.download == .failed)
        #expect(!StubServer.wasRequested(file))
    }

    @Test func theWeeklyCheckFetchesTheCatalogueListedForThisSchema() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        let own = try scene.release(CatalogueFixture.make(books: Self.otherBooks), version: "2027-01")
        try scene.publish(CatalogueFixture.make(), version: "2026-11", schema: Catalogue.schemaVersion - 1, listing: [own.entry])
        let store = scene.store()

        await store.updateIfDue()

        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("kross").map(\.title) == ["Keisri hull"])
        #expect(store.installedVersion == "2027-01")
    }

    // A later schema may name its file in another way, and a build that cannot read
    // that still has to find its own catalogue and know there is a newer one.
    @Test func aCatalogueThisBuildCannotReadStillCountsForItsSchema() throws {
        let json = """
            {"version": "2026-11", "schema_version": 4, "url": "https://loe.test/four.xz", "sha256": "AB12",
             "catalogues": [{"schema_version": 5, "files": ["https://loe.test/five.zst"]}]}
            """
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: Data(json.utf8))

        #expect(manifest.catalogue(forSchema: 4)?.version == "2026-11")
        #expect(manifest.catalogue(forSchema: 4)?.sha256 == "ab12")
        #expect(manifest.catalogue(forSchema: 5) == nil)
        #expect(manifest.hasCatalogue(newerThanSchema: 4))
        #expect(!manifest.hasCatalogue(newerThanSchema: 5))
    }

    @Test func anUpdateReplacesAnOlderCatalogue() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        try scene.publish(CatalogueFixture.make(books: Self.otherBooks), version: "2026-11")
        let store = scene.store()

        await store.updateIfDue()

        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("kross").map(\.title) == ["Keisri hull"])
        #expect(store.installedVersion == "2026-11")
    }

    @Test func updatesAreCheckedAtMostOnceAWeek() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        try scene.publish(CatalogueFixture.make(books: Self.otherBooks), version: "2026-11")
        scene.defaults.set(Date.now.addingTimeInterval(-6 * 24 * 60 * 60), forKey: "catalogueCheckedForUpdate")
        let store = scene.store()

        await store.updateIfDue()

        #expect(!StubServer.wasRequested(scene.manifestURL))
        #expect(store.installedVersion == "2026-10")
    }

    @Test func theCheckIsDueAfterAWeekOrWhenNeverChecked() {
        let now = Date.now
        #expect(CatalogueStore.isUpdateCheckDue(lastChecked: nil, now: now))
        #expect(!CatalogueStore.isUpdateCheckDue(lastChecked: now.addingTimeInterval(-6 * 86_400), now: now))
        #expect(CatalogueStore.isUpdateCheckDue(lastChecked: now.addingTimeInterval(-7 * 86_400), now: now))
    }

    @Test func thePublishedManifestHasACatalogueThisAppCanUse() throws {
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: Data(contentsOf: CatalogueFixture.manifest))
        let published = try #require(manifest.catalogue(forSchema: Catalogue.schemaVersion))
        #expect(published.sha256.count == 64)
        #expect(published.url.absoluteString.contains(published.version))
    }

    // The first builds read the file's top level and nothing else, and they read
    // schema 1, so that is what the top level stays.
    @Test func thePublishedManifestKeepsTheFirstSchemasCatalogueAtItsTopLevel() throws {
        let top = try JSONDecoder().decode(PublishedCatalogue.self, from: Data(contentsOf: CatalogueFixture.manifest))
        #expect(top.schemaVersion == 1)
    }
}
