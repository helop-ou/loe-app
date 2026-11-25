import SwiftUI
import Testing
@testable import Loe

@MainActor
struct BookCoverSnapshotTests {
    private static func picture(_ left: UIColor, _ right: UIColor) -> Data {
        EPIKTests.picture(width: 200, height: 300, left: left, right: right)
    }

    // The card, a found cover the phone has ready, and the reader's own photo. A
    // snapshot is a view's first frame, and nothing answers for the cover, so the
    // found one shows only because it was ready.
    @Test(arguments: Snapshot.Look.all)
    func aCardAFoundCoverAndAPhoto(look: Snapshot.Look) async throws {
        let found = Self.picture(UIColor(red: 0.13, green: 0.3, blue: 0.26, alpha: 1), UIColor(red: 0.2, green: 0.45, blue: 0.38, alpha: 1))
        let photo = Self.picture(UIColor(red: 0.55, green: 0.24, blue: 0.2, alpha: 1), UIColor(red: 0.72, green: 0.36, blue: 0.27, alpha: 1))
        let pictures = CoverPictures()
        _ = try #require(await pictures.picture(of: found, for: .id(1), width: 96, scale: 2))
        let covers = Covers(directory: nil) { _ in (Data(), 404) }
        let row = HStack(alignment: .top, spacing: 14) {
            BookCover(title: "Keisri hull", width: 96)
            BookCover(title: "Kevade", art: .id(1), width: 96, covers: covers, pictures: pictures)
            BookCover(title: "Nukitsamees", photo: photo, width: 96)
        }
        try Snapshot.verify(row.padding(20).frame(maxWidth: .infinity, alignment: .leading), named: "book-cover", look: look)
    }
}
