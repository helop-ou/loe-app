import Foundation
import Testing
@testable import Loe

/// The quiet update: which networks it may use, what happens when it fails, and
/// what an install leaves behind. See docs/catalogue.md, "Download and updates".
struct CatalogueUpdateTests {
    private static let otherBooks = "(1, 'b9', 'Keisri hull', 'Jaan Kross', 1978, 1, 0, NULL, 'est', NULL, NULL)"

    /// A phone with last month's catalogue, and this month's published.
    private func sceneWithANewerEdition(sha256: String? = nil, editions: Int? = nil) throws -> (scene: DownloadScene, file: URL) {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        let file = try scene.publish(
            CatalogueFixture.make(books: Self.otherBooks), version: "2026-11", sha256: sha256, editions: editions
        )
        return (scene, file)
    }

    // Nobody asked for the weekly update, so it leaves mobile data and Low Data
    // Mode alone.
    @Test func aQuietUpdateWaitsForANetworkThatIsNeitherMobileDataNorInLowDataMode() async throws {
        let (scene, file) = try sceneWithANewerEdition()

        await scene.store().updateIfDue()

        let request = try #require(StubServer.requests(for: file).first)
        #expect(!request.allowsExpensiveNetworkAccess)
        #expect(!request.allowsConstrainedNetworkAccess)
    }

    @Test func aDownloadTheReaderAskedForMayUseAnyNetwork() async throws {
        let (scene, file) = try sceneWithANewerEdition()
        await scene.store().checkNow()
        let update = try #require(StubServer.requests(for: file).first)
        #expect(update.allowsExpensiveNetworkAccess)
        #expect(update.allowsConstrainedNetworkAccess)

        let empty = DownloadScene()
        let first = try empty.publish(CatalogueFixture.make(), version: "2026-11")
        await empty.store().downloadCatalogue()
        let download = try #require(StubServer.requests(for: first).first)
        #expect(download.allowsExpensiveNetworkAccess)
        #expect(download.allowsConstrainedNetworkAccess)
    }

    // On mobile data the manifest answers and the download fails at once. Counting
    // that as the week's check kept a reader a week behind for every such launch.
    @Test(arguments: [URLError.Code.notConnectedToInternet, .dataNotAllowed, .networkConnectionLost, .timedOut, .cancelled])
    func anUpdateThatCouldNotBeFetchedIsTriedAgainAtTheNextLaunch(code: URLError.Code) async throws {
        let (scene, file) = try sceneWithANewerEdition()
        StubServer.fail(file, with: code)
        let store = scene.store()

        await store.updateIfDue()

        #expect(store.lastChecked == nil)
        #expect(store.installedVersion == "2026-10")
        #expect(!store.isBusy)

        // The next launch, on a network it may use.
        try scene.publish(CatalogueFixture.make(books: Self.otherBooks), version: "2026-11")
        let next = scene.store()
        let now = Date.now
        await next.updateIfDue(now: now)

        #expect(next.installedVersion == "2026-11")
        #expect(next.lastChecked == now)
        guard case .ready(let catalogue) = next.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("kross").map(\.title) == ["Keisri hull"])
    }

    @Test func anUpdateTheServerDidNotServeIsTriedAgainToo() async throws {
        let (scene, file) = try sceneWithANewerEdition()
        StubServer.serve(file, status: 503, body: Data())
        let store = scene.store()

        await store.updateIfDue()

        #expect(store.lastChecked == nil)
        #expect(store.installedVersion == "2026-10")
    }

    // A file that arrived and is wrong stays wrong until the manifest changes, and
    // fetching 30 MB at every launch to find that out again helps nobody.
    @Test func anUpdateThatArrivedWrongWaitsTheWeek() async throws {
        let (scene, file) = try sceneWithANewerEdition(sha256: String(repeating: "0", count: 64))
        let store = scene.store()
        let now = Date.now

        await store.updateIfDue(now: now)

        #expect(store.lastChecked == now)
        #expect(store.installedVersion == "2026-10")

        await scene.store().updateIfDue(now: now.addingTimeInterval(86_400))
        #expect(StubServer.requests(for: file).count == 1)
        #expect(StubServer.requests(for: scene.manifestURL).count == 1)
    }

    @Test func aCheckWithNothingNewerCountsAtOnce() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11")
        let store = scene.store()
        let now = Date.now

        await store.updateIfDue(now: now)

        #expect(store.lastChecked == now)
        #expect(!StubServer.wasRequested(file))
    }

    @Test func aNetworkFailureIsTheOnlyKindWorthTryingAgainSoon() {
        #expect(CatalogueDownloader.couldNotFetch(URLError(.notConnectedToInternet)))
        #expect(CatalogueDownloader.couldNotFetch(CatalogueDownloader.Failure.badResponse(404)))
        #expect(!CatalogueDownloader.couldNotFetch(CatalogueDownloader.Failure.checksumMismatch))
        #expect(!CatalogueDownloader.couldNotFetch(CatalogueDownloader.Failure.wrongEditionCount(3)))
        #expect(!CatalogueDownloader.couldNotFetch(CatalogueDownloader.Failure.unsupportedSchema(2)))
        #expect(!CatalogueDownloader.couldNotFetch(CocoaError(.fileWriteOutOfSpace)))
    }

    // The manifest counts a catalogue's editions, and a file that unpacked to
    // another number is not the catalogue it describes.
    @Test func aCatalogueWithAnotherNumberOfEditionsThanTheManifestSaysIsNotInstalled() async throws {
        let (scene, _) = try sceneWithANewerEdition(editions: 2)
        let published = try #require(try await scene.downloader.manifest().catalogue(forSchema: Catalogue.schemaVersion))
        #expect(published.editions == 2)

        await #expect(throws: CatalogueDownloader.Failure.wrongEditionCount(1)) {
            try await scene.downloader.install(published, at: scene.catalogueURL)
        }
        let works = try await Catalogue(url: scene.catalogueURL).search("tammsaare")
        #expect(works.map(\.title) == ["Tõde ja õigus"])
        #expect(try leftovers(in: scene) == [])
    }

    @Test func aCatalogueWithTheEditionsTheManifestCountsIsInstalled() async throws {
        let (scene, _) = try sceneWithANewerEdition(editions: 1)
        let store = scene.store()

        await store.updateIfDue()

        #expect(store.installedVersion == "2026-11")
        #expect(try leftovers(in: scene) == [])
    }

    // An install killed while it unpacked leaves a file as large as the catalogue
    // in a folder that is backed up.
    @Test func aLaunchClearsWhatAnInstallThatWasCutOffLeftBehind() throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        let folder = scene.catalogueURL.deletingLastPathComponent()
        let cutOff = folder.appending(path: "\(UUID().uuidString).partial")
        let another = folder.appending(path: "\(UUID().uuidString).partial")
        let kept = folder.appending(path: "notes.txt")
        for file in [cutOff, another, kept] {
            try Data("left behind".utf8).write(to: file)
        }

        let store = scene.store()

        #expect(try leftovers(in: scene) == ["notes.txt"])
        guard case .ready = store.state else { Issue.record("expected ready"); return }
    }

    @Test func aLaunchWithNoCatalogueFolderIsStillALaunch() {
        let store = DownloadScene().store()
        guard case .missing = store.state else { Issue.record("expected missing"); return }
    }

    // While the quiet update replaces the file, nothing else may touch it.
    @Test func nothingElseTouchesTheCatalogueWhileAQuietUpdateRuns() async throws {
        let (scene, file) = try sceneWithANewerEdition()
        let store = scene.store()

        async let update: Void = store.updateIfDue()
        while !store.isBusy, store.installedVersion == "2026-10" { await Task.yield() }
        try #require(store.isBusy)

        await store.checkNow()
        #expect(store.check == nil)
        await store.downloadCatalogue()
        #expect(store.download == nil)
        await store.updateIfDue()
        await store.keepUp()

        await update
        #expect(store.installedVersion == "2026-11")
        #expect(!store.isBusy)
        #expect(StubServer.requests(for: scene.manifestURL).count == 1)
        #expect(StubServer.requests(for: file).count == 1)
    }

    @Test func nothingElseTouchesTheCatalogueWhileTheReadersDownloadRuns() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11")
        let store = scene.store()

        async let download: Void = store.downloadCatalogue()
        while !store.isBusy, store.installedVersion == nil { await Task.yield() }
        try #require(store.isBusy)

        await store.updateIfDue()
        await store.downloadCatalogue()
        await store.keepUp()

        await download
        #expect(store.installedVersion == "2026-11")
        #expect(StubServer.requests(for: scene.manifestURL).count == 1)
        #expect(StubServer.requests(for: file).count == 1)
    }

    /// The files beside the catalogue, which is all an install should leave there.
    private func leftovers(in scene: DownloadScene) throws -> [String] {
        let folder = scene.catalogueURL.deletingLastPathComponent()
        return try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0 != scene.catalogueURL.lastPathComponent }
            .sorted()
    }
}
