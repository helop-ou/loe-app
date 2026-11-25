import Foundation
import Testing
import UIKit
@testable import Loe

/// How a cover is made ready for the screen. These run on the main actor, as a
/// view does, and a debug build stops when a cover is decoded there.
@MainActor
struct CoverPicturesTests {
    private func pixels(_ picture: UIImage?) -> CGSize? {
        picture?.cgImage.map { CGSize(width: $0.width, height: $0.height) }
    }

    /// A search row is 56 points wide, 168 pixels on an iPhone, and Open Library's
    /// large covers are several times that.
    @Test func aCoverIsDecodedNoLargerThanItShows() async {
        let large = EPIKTests.picture(width: 600, height: 900)
        let picture = await CoverPictures().picture(of: large, for: .id(1), width: 56, scale: 3)
        #expect(pixels(picture) == CGSize(width: 168, height: 252))
    }

    /// ESTER's covers are 240 pixels tall, smaller than a book's page shows them.
    @Test func aSmallCoverIsNotEnlarged() async {
        let small = EPIKTests.picture(width: 160, height: 240)
        let picture = await CoverPictures().picture(of: small, for: .id(1), width: 140, scale: 3)
        #expect(pixels(picture) == CGSize(width: 160, height: 240))
    }

    /// A cover of another shape is cut to a book's, so it has to reach both edges.
    @Test func aCoverOfAnotherShapeStillFillsItsFrame() async {
        let wide = EPIKTests.picture(width: 900, height: 600)
        let picture = await CoverPictures().picture(of: wide, for: .id(1), width: 56, scale: 3)
        #expect(pixels(picture) == CGSize(width: 378, height: 252))
        #expect(CoverPictures.longestSide(of: CGSize(width: 900, height: 600), filling: CGSize(width: 168, height: 252)) == 378)
        #expect(CoverPictures.longestSide(of: CGSize(width: 600, height: 900), filling: CGSize(width: 168, height: 252)) == 252)
        #expect(CoverPictures.longestSide(of: CGSize(width: 160, height: 240), filling: CGSize(width: 420, height: 630)) == 240)
    }

    /// What lets a cover show with a view's first frame.
    @Test func aPictureMadeOnceIsReady() async throws {
        let pictures = CoverPictures()
        let cover = EPIKTests.picture(width: 160, height: 240)
        #expect(pictures.ready(.id(1), width: 56) == nil)
        let made = try #require(await pictures.picture(of: cover, for: .id(1), width: 56, scale: 3))
        #expect(pictures.ready(.id(1), width: 56) === made)
        #expect(await pictures.picture(of: cover, for: .id(1), width: 56, scale: 3) === made)
        // Another book, or the same one at another size, has its own.
        #expect(pictures.ready(.id(2), width: 56) == nil)
        #expect(pictures.ready(.id(1), width: 140) == nil)
    }

    @Test func somethingThatIsNotAnImageGivesNoPicture() async {
        let pictures = CoverPictures()
        #expect(await pictures.picture(of: Data("not an image".utf8), for: .id(1), width: 56, scale: 3) == nil)
        #expect(pictures.ready(.id(1), width: 56) == nil)
    }
}
