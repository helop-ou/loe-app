import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Loe

/// Renders a view the way a reader sees it and compares it with a reference PNG in
/// LoeTests/Snapshots/iOS-<version>. Text renders a little differently on each iOS
/// version, so references are kept per runtime, and on a runtime without a folder
/// the view is only rendered and attached. Inside the folder a missing reference is
/// written and the test fails once, so look at the new PNG before committing it.
/// Delete a reference to record it again, or create a folder for a new runtime.
@MainActor
enum Snapshot {
    nonisolated struct Look: Sendable, CustomTestStringConvertible {
        let name: String
        var dark = false
        var language = "en"
        var size = DynamicTypeSize.large

        var testDescription: String { name }

        static let all = [
            Look(name: "light-en"),
            Look(name: "dark-et", dark: true, language: "et"),
            Look(name: "accessibility-et", language: "et", size: .accessibility3),
        ]
    }

    /// The width of an iPhone 17 Pro.
    static let width: CGFloat = 402
    /// The share of pixels that may differ, for antialiasing.
    static let tolerance = 0.001

    private static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Snapshots/iOS-\(UIDevice.current.systemVersion)")

    static func verify(_ view: some View, named name: String, look: Look) throws {
        let (image, png) = try #require(
            firstSuccess(in: 3) { render(view, look: look).flatMap { image in pngData(image).map { (image, $0) } } },
            "\(name)-\(look.name) could not be rendered and made into a PNG"
        )
        Attachment.record(png, named: "\(name)-\(look.name).png")

        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let reference = directory.appending(path: "\(name)-\(look.name).png")
        guard let expected = CGImageSourceCreateWithURL(reference as CFURL, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else {
            try png.write(to: reference)
            Issue.record("Recorded \(reference.lastPathComponent). Look at it, then run again.")
            return
        }
        let difference = try #require(differingShare(image, expected))
        #expect(difference <= tolerance, "\(Int(difference * 100))% of \(reference.lastPathComponent) differs")
    }

    /// The first answer `make` gives in this many goes. On a busy CI runner the
    /// renderer now and then hands back an image no PNG can be made from.
    static func firstSuccess<Value>(in attempts: Int, _ make: () -> Value?) -> Value? {
        for _ in 0..<attempts {
            if let value = make() { return value }
        }
        return nil
    }

    private static func render(_ view: some View, look: Look) -> CGImage? {
        let renderer = ImageRenderer(content: view
            .frame(width: width)
            .background(Color.loeBackground)
            .environment(\.colorScheme, look.dark ? .dark : .light)
            .environment(\.locale, Locale(identifier: look.language))
            .environment(\.dynamicTypeSize, look.size))
        renderer.scale = 2
        return renderer.cgImage
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The share of pixels that differ visibly, or 1 when the sizes differ.
    private static func differingShare(_ a: CGImage, _ b: CGImage) -> Double? {
        guard a.width == b.width, a.height == b.height else { return 1 }
        guard let first = rgba(a), let second = rgba(b) else { return nil }
        var differing = 0
        for pixel in stride(from: 0, to: first.count, by: 4) {
            for channel in 0..<4 where abs(Int(first[pixel + channel]) - Int(second[pixel + channel])) > 8 {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(a.width * a.height)
    }

    private static func rgba(_ image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }
}
