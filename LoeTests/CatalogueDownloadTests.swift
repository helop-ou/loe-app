import Foundation
import Synchronization
import Testing
@testable import Loe

/// Serves canned responses to a URLSession, and records what was asked for.
nonisolated final class StubServer: URLProtocol {
    private static let responses = Mutex<[URL: (status: Int, body: Data)]>([:])
    private static let requested = Mutex<[URL]>([])

    static func serve(_ url: URL, status: Int = 200, body: Data) {
        responses.withLock { $0[url] = (status, body) }
    }

    static func wasRequested(_ url: URL) -> Bool {
        requested.withLock { $0.contains(url) }
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
        Self.requested.withLock { $0.append(url) }
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

    /// Publishes a catalogue the way a release does: the xz file and a manifest naming it.
    @discardableResult
    func publish(
        _ catalogue: URL,
        version: String,
        schema: Int = Catalogue.schemaVersion,
        sha256: String? = nil
    ) throws -> URL {
        let file = host.appending(path: "catalogue-\(version).sqlite.xz")
        let compressed = try CatalogueFixture.xz(of: catalogue)
        StubServer.serve(file, body: compressed)
        let checksum = try sha256 ?? {
            let temporary = URL.temporaryDirectory.appending(path: UUID().uuidString)
            try compressed.write(to: temporary)
            return try CatalogueDownloader.sha256(of: temporary)
        }()
        let manifest = """
            {"version": "\(version)", "schema_version": \(schema), "url": "\(file.absoluteString)",
             "sha256": "\(checksum)", "size": \(compressed.count)}
            """
        StubServer.serve(manifestURL, body: Data(manifest.utf8))
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
    private static let otherBooks = "(1, 'b9', 'Keisri hull', 'Jaan Kross', 1978, 1, 0, NULL)"

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
        let manifest = try await scene.downloader.manifest()

        await #expect(throws: CatalogueDownloader.Failure.checksumMismatch) {
            try await scene.downloader.install(manifest, at: scene.catalogueURL)
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
        let manifest = try await scene.downloader.manifest()

        await #expect(throws: (any Error).self) {
            try await scene.downloader.install(manifest, at: scene.catalogueURL)
        }
        let works = try await Catalogue(url: scene.catalogueURL).search("tammsaare")
        #expect(works.map(\.title) == ["Tõde ja õigus"])
    }

    @Test func aCatalogueForANewerAppIsNotDownloaded() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2027-01", schema: Catalogue.schemaVersion + 1)
        let manifest = try await scene.downloader.manifest()

        await #expect(throws: CatalogueDownloader.Failure.unsupportedSchema(Catalogue.schemaVersion + 1)) {
            try await scene.downloader.install(manifest, at: scene.catalogueURL)
        }
        #expect(!StubServer.wasRequested(file))
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

    @Test func thePublishedManifestIsOneThisAppCanUse() throws {
        let manifest = try JSONDecoder().decode(CatalogueManifest.self, from: Data(contentsOf: CatalogueFixture.manifest))
        #expect(manifest.schemaVersion == Catalogue.schemaVersion)
        #expect(manifest.sha256.count == 64)
        #expect(manifest.url.absoluteString.contains(manifest.version))
    }
}
