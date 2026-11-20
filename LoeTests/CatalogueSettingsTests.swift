import Foundation
import Testing
@testable import Loe

/// What Settings does with the catalogue: look for a new edition when the reader
/// asks, say what came of it, and remove it.
struct CatalogueSettingsTests {
    private static let otherBooks = "(1, 'b9', 'Keisri hull', 'Jaan Kross', 1978, 1, 0, NULL, 'est', NULL, NULL)"

    @Test func checkingNowFetchesANewerEdition() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        try scene.publish(CatalogueFixture.make(books: Self.otherBooks), version: "2026-11")
        // Checked yesterday, so the weekly check would not look yet.
        scene.defaults.set(Date.now.addingTimeInterval(-86_400), forKey: "catalogueCheckedForUpdate")
        let store = scene.store()
        let now = Date.now

        await store.checkNow(now: now)

        #expect(store.check == .updated)
        #expect(store.download == nil)
        #expect(store.installedVersion == "2026-11")
        #expect(store.lastChecked == now)
        guard case .ready(let catalogue) = store.state else { Issue.record("expected ready"); return }
        #expect(try await catalogue.search("kross").map(\.title) == ["Keisri hull"])
        #expect(try await catalogue.editionCount() == 1)
    }

    @Test func checkingNowSaysWhenThereIsNothingNewer() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11")
        let store = scene.store()

        await store.checkNow()

        #expect(store.check == .upToDate)
        #expect(store.lastChecked != nil)
        #expect(!StubServer.wasRequested(file))
    }

    @Test func checkingNowSaysWhenTheNewestNeedsANewerLoe() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11", schema: Catalogue.schemaVersion + 1)
        let store = scene.store()

        await store.checkNow()

        #expect(store.check == .needsNewerLoe)
        #expect(store.installedVersion == "2026-10")
        #expect(!StubServer.wasRequested(file))
    }

    @Test func aCheckThatFailsKeepsTheCatalogueAndIsNotCounted() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-10")
        let store = scene.store()

        await store.checkNow()
        #expect(store.check == .failed)
        #expect(store.lastChecked == nil)
        guard case .ready = store.state else { Issue.record("expected ready"); return }

        // The quiet weekly check is not counted either, so the next launch asks again.
        await store.updateIfDue()
        #expect(store.lastChecked == nil)
    }

    @Test func removingFreesTheSpaceAndForgetsTheEdition() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        scene.defaults.set(Date.now, forKey: "catalogueCheckedForUpdate")
        let store = scene.store()
        #expect(store.sizeOnDisk ?? 0 > 0)

        try store.remove()

        guard case .missing = store.state else { Issue.record("expected missing"); return }
        #expect(!FileManager.default.fileExists(atPath: scene.catalogueURL.path))
        #expect(store.installedVersion == nil)
        #expect(store.lastChecked == nil)
        #expect(store.sizeOnDisk == nil)

        // Gone for good: the weekly check does not bring it back.
        try scene.publish(CatalogueFixture.make(), version: "2026-12")
        await store.updateIfDue()
        guard case .missing = store.state else { Issue.record("expected missing"); return }
    }

    @Test func anEditionIsNamedByItsMonth() throws {
        let month = try #require(CatalogueManifest.month(ofVersion: "2026-11"))
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: month)
        #expect(parts.year == 2026)
        #expect(parts.month == 11)
        #expect(CatalogueManifest.month(ofVersion: "2026-13") == nil)
        #expect(CatalogueManifest.month(ofVersion: "november") == nil)
        #expect(CatalogueManifest.month(ofVersion: "2026-11-02") == nil)
    }
}
