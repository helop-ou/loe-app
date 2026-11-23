import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Loe

/// Renders a view the way a reader sees it and compares it with a reference PNG in
/// LoeTests/Snapshots/iOS-<version>. Text renders a little differently on each iOS
/// version, so references are kept per runtime, and a run on a runtime without a
/// folder fails unless it asked to only render. Inside the folder a missing
/// reference is written and the test fails once, so look at the new PNG before
/// committing it. Delete a reference to record it again, or create a folder for a
/// new runtime.
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

    /// What draws the view. The renderer is enough for a plain piece of a screen. A
    /// window draws what the renderer leaves out: native controls such as a progress
    /// bar, and rows that scroll sideways. It holds the view in a scroll view, as a
    /// screen does, so text takes the lines it needs.
    nonisolated enum Canvas: Sendable {
        case renderer
        case window
    }

    /// The width of an iPhone 17 Pro.
    static let width: CGFloat = 402
    /// How many pixels may differ. A count and not a share of the image, so a
    /// changed icon fails however tall the snapshot is.
    static let budget = 10

    static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Snapshots/iOS-\(UIDevice.current.systemVersion)")

    /// Whether this run asked to only render where its iOS has no references:
    /// `TEST_RUNNER_LOE_SNAPSHOTS_RENDER_ONLY=1 xcodebuild test`.
    static let rendersOnly = ProcessInfo.processInfo.environment["LOE_SNAPSHOTS_RENDER_ONLY"] != nil

    /// What became of a snapshot.
    enum Outcome: Equatable {
        case matches
        /// The run asked to only render, and its iOS has no references.
        case renderedOnly
        case noReferences(folder: String)
        case recorded(String)
        case differs(String, pixels: Int)

        /// What the test fails with, or nil when nothing is wrong.
        var problem: String? {
            switch self {
            case .matches, .renderedOnly:
                nil
            case .noReferences(let folder):
                """
                No references for this iOS: \(folder) is not in LoeTests/Snapshots. Create the folder to record \
                them and look at each PNG before committing it, or run with \
                TEST_RUNNER_LOE_SNAPSHOTS_RENDER_ONLY=1 to only render.
                """
            case .recorded(let file):
                "Recorded \(file). Look at it, then run again."
            case .differs(let file, let pixels):
                "\(pixels) pixels of \(file) differ, and \(Snapshot.budget) may"
            }
        }
    }

    static func verify(_ view: some View, named name: String, look: Look, on canvas: Canvas = .renderer) throws {
        let outcome = try outcome(of: view, named: name, look: look, on: canvas, in: directory, rendersOnly: rendersOnly)
        if let problem = outcome.problem {
            Issue.record(Comment(rawValue: problem))
        }
    }

    static func outcome(
        of view: some View, named name: String, look: Look, on canvas: Canvas = .renderer, in directory: URL, rendersOnly: Bool
    ) throws -> Outcome {
        let file = "\(name)-\(look.name).png"
        let (image, png) = try #require(
            firstSuccess(in: 3) { render(view, look: look, on: canvas).flatMap { image in pngData(image).map { (image, $0) } } },
            "\(name)-\(look.name) could not be rendered and made into a PNG"
        )
        Attachment.record(png, named: file)

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return rendersOnly ? .renderedOnly : .noReferences(folder: directory.lastPathComponent)
        }
        let reference = directory.appending(path: file)
        guard let expected = CGImageSourceCreateWithURL(reference as CFURL, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else {
            try png.write(to: reference)
            return .recorded(file)
        }
        let differing = try #require(differingPixels(image, expected))
        return differing <= budget ? .matches : .differs(file, pixels: differing)
    }

    /// The first answer `make` gives in this many goes. On a busy CI runner the
    /// renderer now and then hands back an image no PNG can be made from.
    static func firstSuccess<Value>(in attempts: Int, _ make: () -> Value?) -> Value? {
        for _ in 0..<attempts {
            if let value = make() { return value }
        }
        return nil
    }

    private static func render(_ view: some View, look: Look, on canvas: Canvas) -> CGImage? {
        switch canvas {
        case .renderer:
            let renderer = ImageRenderer(content: dressed(view.frame(width: width), look: look))
            renderer.scale = 2
            return renderer.cgImage
        case .window:
            return renderInWindow(dressed(ScrollView { view }.scrollIndicators(.hidden).frame(width: width), look: look), dark: look.dark)
        }
    }

    private static func dressed(_ view: some View, look: Look) -> some View {
        view
            .background(Color.loeBackground)
            .environment(\.colorScheme, look.dark ? .dark : .light)
            .environment(\.locale, Locale(identifier: look.language))
            .environment(\.dynamicTypeSize, look.size)
    }

    /// Lays the view out in a window of the app the tests run in, as tall as what
    /// its scroll view holds, and draws the window's layers.
    private static func renderInWindow(_ view: some View, dark: Bool) -> CGImage? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = dark ? .dark : .light
        controller.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }
        func layOut(height: CGFloat) {
            window.frame = CGRect(x: 0, y: 0, width: width, height: height)
            controller.view.frame = window.bounds
            controller.view.layoutIfNeeded()
        }
        window.rootViewController = controller
        window.isHidden = false
        layOut(height: 800)
        guard let content = scrollView(in: controller.view)?.contentSize.height, content > 0 else { return nil }
        layOut(height: content.rounded(.up))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            controller.view.layer.render(in: context.cgContext)
        }.cgImage
    }

    private static func scrollView(in view: UIView) -> UIScrollView? {
        (view as? UIScrollView) ?? view.subviews.lazy.compactMap(scrollView(in:)).first
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// How many pixels differ visibly, or every pixel when the sizes differ. A
    /// pixel a shade apart, as antialiasing leaves it, is not a difference.
    static func differingPixels(_ a: CGImage, _ b: CGImage) -> Int? {
        guard a.width == b.width, a.height == b.height else { return max(a.width * a.height, b.width * b.height) }
        guard let first = rgba(a), let second = rgba(b) else { return nil }
        var differing = 0
        for pixel in stride(from: 0, to: first.count, by: 4) {
            for channel in 0..<4 where abs(Int(first[pixel + channel]) - Int(second[pixel + channel])) > 8 {
                differing += 1
                break
            }
        }
        return differing
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
