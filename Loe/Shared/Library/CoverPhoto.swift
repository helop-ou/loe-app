import UIKit

/// A reader's photo of a cover, ready to keep: shrunk to a size that syncs quickly,
/// with its colour read once so nothing has to decode it again.
nonisolated struct CoverPhoto: Sendable {
    let jpeg: Data
    let sample: LoeTone.Sample

    /// Tall enough for a cover filling 40% of the widest phone at 3x.
    static let maximumHeight: CGFloat = 900

    init?(_ image: UIImage) {
        let scale = min(1, Self.maximumHeight / max(image.size.height, 1))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8),
              let cgImage = resized.cgImage,
              let sample = LoeTone.sample(from: cgImage)
        else { return nil }
        self.jpeg = jpeg
        self.sample = sample
    }
}
