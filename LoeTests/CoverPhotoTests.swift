import SwiftData
import Testing
import UIKit
@testable import Loe

struct CoverPhotoTests {
    private func photo(_ color: UIColor, width: CGFloat = 2000, height: CGFloat = 3000) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func aPhotoIsShrunkToSyncQuickly() throws {
        let cover = try #require(CoverPhoto(photo(.red)))
        let kept = try #require(UIImage(data: cover.jpeg))
        #expect(kept.size.height == CoverPhoto.maximumHeight)
        #expect(kept.size.width == 600)
        #expect(cover.jpeg.count < 200_000)
    }

    @Test func aSmallPhotoIsNotEnlarged() throws {
        let cover = try #require(CoverPhoto(photo(.red, width: 200, height: 300)))
        #expect(UIImage(data: cover.jpeg)?.size.height == 300)
    }

    @Test func itsColourIsReadOnce() throws {
        let red = try #require(CoverPhoto(photo(UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))))
        #expect(red.sample.hue < 0.02 || red.sample.hue > 0.98)
        #expect(red.sample.saturation > 0.8)
        let grey = try #require(CoverPhoto(photo(.gray)))
        #expect(grey.sample.saturation < 0.05)
        #expect(CoverWash.color(grey.sample, dark: false, surface: .page) == nil)
    }

    @Test func aShelvedBookKeepsAndForgetsItsCover() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let edition = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross")
        let work = CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
        let book = try ShelvedBook.shelve(work, edition: edition, on: .read, in: ModelContext(container))
        book.rate(5)

        book.setCover(CoverPhoto(photo(.blue)))
        #expect(book.coverPhoto != nil)
        #expect(book.coverSample?.weight == 5)
        #expect(abs((book.coverSample?.hue ?? 0) - 0.667) < 0.01)

        book.setCover(nil)
        #expect(book.coverPhoto == nil)
        #expect(book.coverHue == nil)
        #expect(book.coverSaturation == nil)
        #expect(book.coverSample == nil)
    }
}
