import Foundation
import Testing
@testable import Loe

/// The catalogue manifest can turn off everything Loe asks ESTER, and nothing on.
/// See docs/library.md, "Turning ESTER off".
struct ESTERSwitchTests {
    private func manifest(saying extra: String) throws -> CatalogueManifest {
        let json = #"{"version": "2026-11", "schema_version": 1, "url": "https://loe.test/c.xz", "sha256": "ab12"\#(extra)}"#
        return try JSONDecoder().decode(CatalogueManifest.self, from: Data(json.utf8))
    }

    @Test func aManifestThatSaysNothingLeavesESTEROn() throws {
        #expect(try manifest(saying: "").asksESTER)
        #expect(try manifest(saying: #", "asks_ester": true"#).asksESTER)
    }

    // A slip in the file must not leave ESTER on when it was meant to be off.
    @Test(arguments: ["false", "null", "0", #""false""#, #""off""#, "[]", "{}"])
    func anythingButTrueTurnsESTEROff(value: String) throws {
        let manifest = try manifest(saying: #", "asks_ester": \#(value)"#)
        #expect(!manifest.asksESTER)
        // The catalogue is still read: the switch is not a reason to lose it.
        #expect(manifest.catalogue(forSchema: 1)?.version == "2026-11")
    }

    // What a manifest said is kept under this name on every phone, so it stays.
    @Test func theLastWordIsKeptUnderOneName() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        #expect(ESTERSwitch.key == "asksESTER")
        #expect(ESTERSwitch.isOn(in: defaults))
        defaults.set(false, forKey: "asksESTER")
        #expect(!ESTERSwitch.isOn(in: defaults))
        defaults.set(true, forKey: "asksESTER")
        #expect(ESTERSwitch.isOn(in: defaults))
    }

    @Test func theWeeklyCheckTurnsESTEROffAndTheNextLaunchStartsWithItOff() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        try scene.publish(CatalogueFixture.make(), version: "2026-11", asksESTER: "false")
        let store = scene.store()
        #expect(store.asksESTER)

        await store.updateIfDue()

        #expect(!store.asksESTER)
        #expect(!scene.store().asksESTER)
    }

    // Shelves that came from iCloud ask ESTER for covers with no catalogue on the phone.
    @Test func aPhoneWithNoCatalogueStillHearsIt() async throws {
        let scene = DownloadScene()
        let file = try scene.publish(CatalogueFixture.make(), version: "2026-11", asksESTER: "false")
        let store = scene.store()
        let now = Date.now

        await store.updateIfDue(now: now)

        #expect(!store.asksESTER)
        #expect(store.lastChecked == now)
        // Hearing it downloads nothing: the catalogue is still the reader's to ask for.
        guard case .missing = store.state else { Issue.record("expected missing"); return }
        #expect(!StubServer.wasRequested(file))

        // And no more than once a week.
        try scene.publish(CatalogueFixture.make(), version: "2026-11")
        await store.updateIfDue(now: now.addingTimeInterval(6 * 86_400))
        #expect(!store.asksESTER)
        await store.updateIfDue(now: now.addingTimeInterval(7 * 86_400))
        #expect(store.asksESTER)
    }

    @Test func theFirstDownloadHearsIt() async throws {
        let scene = DownloadScene()
        try scene.publish(CatalogueFixture.make(), version: "2026-11", asksESTER: "false")
        let store = scene.store()

        await store.downloadCatalogue()

        #expect(!store.asksESTER)
        guard case .ready = store.state else { Issue.record("expected ready"); return }
    }

    @Test func checkingForANewEditionHearsIt() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        try scene.publish(CatalogueFixture.make(), version: "2026-11", asksESTER: "false")
        let store = scene.store()

        await store.checkNow()

        #expect(!store.asksESTER)
        #expect(store.check == .upToDate)
    }

    @Test func aManifestThatNoLongerSaysSoTurnsESTERBackOn() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        scene.defaults.set(false, forKey: "asksESTER")
        try scene.publish(CatalogueFixture.make(), version: "2026-11")
        let store = scene.store()
        #expect(!store.asksESTER)

        await store.updateIfDue()

        #expect(store.asksESTER)
        #expect(scene.store().asksESTER)
    }

    @Test func aManifestThatCannotBeReachedChangesNothing() async throws {
        let scene = DownloadScene()
        try scene.install(CatalogueFixture.make(), version: "2026-11")
        scene.defaults.set(false, forKey: "asksESTER")
        let store = scene.store()

        await store.updateIfDue()
        await store.checkNow()

        #expect(!store.asksESTER)
        #expect(!scene.store().asksESTER)
    }

    @Test func aCoverOfESTERsIsNotLookedForWhileESTERIsOff() {
        let esters = CoverArt.ester(["b1054421"], title: "Keisri hull")
        #expect(esters.allowed(asksESTER: true) == esters)
        #expect(esters.allowed(asksESTER: false) == nil)
        // Open Library has no switch.
        #expect(CoverArt.id(7).allowed(asksESTER: false) == .id(7))
        #expect(CoverArt.isbn("9780345451323").allowed(asksESTER: false) == .isbn("9780345451323"))
    }
}
