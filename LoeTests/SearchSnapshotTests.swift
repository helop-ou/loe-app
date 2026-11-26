import SwiftUI
import Testing
@testable import Loe

@MainActor
struct SearchSnapshotTests {
    private static func work(_ id: Int, _ title: String, by author: String, _ year: Int) -> CatalogueWork {
        // Records no other test has a picture for.
        let edition = CatalogueEdition(id: id, erbID: "b9000\(id)001", title: title, authors: author, year: year, language: "est")
        return CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
    }

    // A book whose cover the phone already has, one on a shelf with the reader's
    // own photo, and one with neither, which shows its card. A snapshot is a
    // view's first frame, so the first shows only a cover that was ready.
    @Test(arguments: Snapshot.Look.all)
    func resultsWithTheCoversThePhoneHas(look: Snapshot.Look) async throws {
        let kept = Self.work(1, "Keisri hull", by: "Jaan Kross", 1978)
        let cover = EPIKTests.picture(
            width: 160, height: 240,
            left: UIColor(red: 0.13, green: 0.3, blue: 0.26, alpha: 1), right: UIColor(red: 0.2, green: 0.45, blue: 0.38, alpha: 1)
        )
        let photo = EPIKTests.picture(
            width: 200, height: 300,
            left: UIColor(red: 0.55, green: 0.24, blue: 0.2, alpha: 1), right: UIColor(red: 0.72, green: 0.36, blue: 0.27, alpha: 1)
        )
        let art = try #require(ListedCover.art(for: kept))
        _ = try #require(await CoverPictures.shared.picture(of: cover, for: art, width: 56, scale: 2))
        let rows = VStack(alignment: .leading, spacing: 0) {
            SearchResultRow(work: kept)
            SearchResultRow(work: Self.work(2, "Kevade", by: "Oskar Luts", 1912), photo: photo)
            SearchResultRow(work: Self.work(3, "Mees, kes teadis ussisõnu", by: "Andrus Kivirähk", 2007))
        }
        try Snapshot.verify(
            rows.padding(.horizontal, 20).frame(maxWidth: .infinity, alignment: .leading), named: "search-results", look: look
        )
    }

    // Search with no catalogue on the phone, when every one there is needs a newer
    // Loe. A window, for the button.
    @Test(arguments: Snapshot.Look.all)
    func aLoeTooOldForTheCatalogue(look: Snapshot.Look) async throws {
        let scene = DownloadScene()
        try scene.publish(CatalogueFixture.make(), version: "2027-01", schema: Catalogue.schemaVersion + 1)
        let store = scene.store()
        await store.downloadCatalogue()
        try Snapshot.verify(CatalogueDownloadView().environment(store), named: "catalogue-too-old", look: look, on: .window)
    }
}
