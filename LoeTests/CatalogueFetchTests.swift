import Foundation
import Testing
@testable import Loe

/// A phone with no catalogue fetches it without being asked: quietly, again at
/// each launch until it has it, and saying so when only mobile data or Low Data
/// Mode stands in the way. See docs/catalogue.md, "Download and updates".
struct CatalogueFetchTests {
    /// What a download fails with when the only network is one it was told to
    /// leave alone.
    private static func unavailable(_ reason: URLError.NetworkUnavailableReason) -> URLError {
        URLError(.notConnectedToInternet, userInfo: [NSURLErrorNetworkUnavailableReasonKey: reason.rawValue])
    }

    @Test func aPhoneWithNoCatalogueFetchesItWithoutBeingAsked() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11", asksESTER: "false")
        let store = scene.store()

        await store.keepUp()

        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("tammsaare").map(\.title) == ["Tõde ja õigus"])
        #expect(store.download == nil)
        #expect(store.installedVersion == "2026-11")
        // Nobody asked for it, so it leaves mobile data and Low Data Mode alone.
        let request = try #require(StubServer.requests(for: file).first)
        #expect(!request.allowsExpensiveNetworkAccess)
        #expect(!request.allowsConstrainedNetworkAccess)
        // The manifest it read on the way is heard like any other.
        #expect(!store.asksESTER)
    }

    @Test(arguments: [URLError.NetworkUnavailableReason.cellular, .expensive, .constrained])
    func onANetworkItLeavesAloneItWaitsAndTheReaderCanAskForItNow(reason: URLError.NetworkUnavailableReason) async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11")
        StubServer.fail(file, with: Self.unavailable(reason))
        let store = scene.store()

        await store.keepUp()

        #expect(store.download == .waitingForWiFi)
        #expect(!store.isBusy)
        guard case .missing = store.state else { Issue.record("expected missing"); return }

        // One tap, and the same network will do.
        try scene.publish(CatalogueFixture.make(), version: "2026-11")
        await store.downloadCatalogue()

        guard case .ready = store.state else { Issue.record("expected ready"); return }
        #expect(store.download == nil)
        let asked = try #require(StubServer.requests(for: file).last)
        #expect(asked.allowsExpensiveNetworkAccess)
        #expect(asked.allowsConstrainedNetworkAccess)
    }

    @Test func aDownloadThatFailsAnotherWaySaysSoAndIsTriedAgainAtTheNextLaunch() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11")
        StubServer.fail(file, with: .timedOut)
        let store = scene.store()

        await store.keepUp()
        #expect(store.download == .failed)

        // No week to wait: a phone with no catalogue asks every time.
        await store.keepUp()
        #expect(StubServer.requests(for: scene.manifestURL).count == 2)
        #expect(store.download == .failed)

        try scene.publish(CatalogueFixture.make(), version: "2026-11")
        let next = scene.store()
        await next.keepUp()
        guard case .ready = next.state else { Issue.record("expected ready"); return }
    }

    @Test func withNoNetworkAtAllItHasFailedAndIsNotWaitingForWiFi() async {
        let scene = DownloadScene()
        StubServer.fail(scene.manifestURL, with: .notConnectedToInternet)
        let store = scene.store()

        await store.keepUp()

        #expect(store.download == .failed)
    }

    // The reader's own download may use any network, so when it fails there is no
    // Wi-Fi to wait for.
    @Test func theReadersOwnDownloadNeverWaitsForWiFi() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11")
        StubServer.fail(file, with: Self.unavailable(.expensive))
        let store = scene.store()

        await store.downloadCatalogue()

        #expect(store.download == .failed)
    }

    @Test func onlyANetworkThatIsLeftAloneIsWorthWaitingFor() {
        #expect(CatalogueDownloader.waitsForWiFi(Self.unavailable(.cellular)))
        #expect(CatalogueDownloader.waitsForWiFi(Self.unavailable(.expensive)))
        #expect(CatalogueDownloader.waitsForWiFi(Self.unavailable(.constrained)))
        #expect(!CatalogueDownloader.waitsForWiFi(URLError(.notConnectedToInternet)))
        #expect(!CatalogueDownloader.waitsForWiFi(URLError(.timedOut)))
        #expect(!CatalogueDownloader.waitsForWiFi(CatalogueDownloader.Failure.checksumMismatch))
    }

    @Test func aPhoneTooOldForEveryCatalogueSaysSo() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2027-01", schema: Catalogue.schemaVersion + 1)
        let store = scene.store()

        await store.keepUp()

        #expect(store.download == .needsNewerLoe)
        #expect(!StubServer.wasRequested(file))
    }

    // A file from a newer Loe, or a damaged one, is in the way of the catalogue
    // as much as no file is.
    @Test func aCatalogueThatCannotBeReadIsFetchedAgain() async throws {
        let scene = DownloadScene()
        try FileManager.default.createDirectory(at: scene.catalogueURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a catalogue".utf8).write(to: scene.catalogueURL)
        try scene.publish(CatalogueFixture.make(), version: "2026-11")
        let store = scene.store()
        guard case .unreadable = store.state else { Issue.record("expected unreadable"); return }

        await store.keepUp()

        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("tammsaare").map(\.title) == ["Tõde ja õigus"])
    }

    // With a catalogue on the phone a launch is the weekly look, as before.
    @Test func aPhoneWithACatalogueLooksForANewerOneOnceAWeek() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        try scene.publish(CatalogueFixture.make(), version: "2026-11")
        scene.defaults.set(Date.now.addingTimeInterval(-6 * 86_400), forKey: "catalogueCheckedForUpdate")
        let store = scene.store()

        await store.keepUp()
        #expect(!StubServer.wasRequested(scene.manifestURL))
        #expect(store.installedVersion == "2026-10")

        await store.keepUp(now: .now.addingTimeInterval(86_400))
        #expect(store.installedVersion == "2026-11")
        #expect(store.download == nil)
    }
}
