import ImageIO
import UIKit

/// Covers decoded for the screen. A cover is decoded off the main actor, no larger
/// than it shows, before it takes its card's place, so a list does not stutter as
/// its covers arrive. The picture is kept while the phone has room for it and is
/// there with a view's first frame, so a cover shown once does not show its card
/// again. See docs/library.md, "Covers".
final class CoverPictures {
    static let shared = CoverPictures()

    private let cache = NSCache<NSString, UIImage>()

    /// At most this much is kept decoded, and less when the phone runs short.
    init(megabytes: Int = 64) {
        cache.totalCostLimit = megabytes * 1024 * 1024
    }

    /// The picture made before for this cover at this width, or nil.
    func ready(_ art: CoverArt, width: CGFloat) -> UIImage? {
        cache.object(forKey: Self.key(art, width))
    }

    /// The cover decoded to fill the 2:3 shape of a book at this width, on a screen
    /// of this scale. Nil when it is not an image.
    func picture(of cover: Data, for art: CoverArt, width: CGFloat, scale: CGFloat) async -> UIImage? {
        if let ready = ready(art, width: width) { return ready }
        let frame = CGSize(width: width * scale, height: width * 1.5 * scale)
        guard let picture = await Self.decoded(cover, filling: frame) else { return nil }
        let bytes = picture.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(picture, forKey: Self.key(art, width), cost: bytes)
        return picture
    }

    private static func key(_ art: CoverArt, _ width: CGFloat) -> NSString {
        "\(art.fileName)@\(Int(width.rounded()))" as NSString
    }

    /// The image decoded then and there, shrunk until it just fills the frame.
    /// Never on the main actor, which would hold up scrolling.
    @concurrent
    nonisolated static func decoded(_ data: Data, filling frame: CGSize) async -> UIImage? {
        #if DEBUG
        // Fails the tests if this ever runs where the caller does.
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double, width > 0,
              let height = properties[kCGImagePropertyPixelHeight] as? Double, height > 0
        else { return nil }
        // A picture stored on its side is turned as it is decoded.
        let onItsSide = (properties[kCGImagePropertyOrientation] as? Int).map { $0 >= 5 } ?? false
        let size = onItsSide ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide(of: size, filling: frame),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }

    /// The longest side, in pixels, of a picture shrunk until it just fills the
    /// frame. A picture smaller than the frame keeps its size: none is enlarged.
    nonisolated static func longestSide(of size: CGSize, filling frame: CGSize) -> Int {
        let fill = max(frame.width / size.width, frame.height / size.height)
        // A hair under before rounding up, or 252 pixels worked out as 252.00000000000003 become 253.
        return Int((max(size.width, size.height) * min(fill, 1) - 0.01).rounded(.up))
    }
}
