import XCTest

/// A journey through the real app. Every journey launches Loe through here, so
/// they all start the same way: in English on a light phone, on an empty
/// in-memory library, searching the small catalogue in `JourneyCatalogue`, and
/// off the network. See docs/standards.md, "Review and verification".
class JourneyTestCase: XCTestCase {
    /// Keeps the quiz away. A journey about the quiz passes its own.
    static let quizSeen = ["-tasteQuizSeen", "YES"]

    /// What the two journeys that can't do with a stand-in ask for.
    enum Real {
        /// The catalogue installed on the simulator, for the README screens.
        case catalogue
        /// The network and no catalogue yet, for the download.
        case download
    }

    /// Loe with what every journey passes it, not yet launched.
    @MainActor
    static func application(_ extra: [String] = quizSeen, real: Real? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_EE", "-inMemoryLibrary", "YES"]
        if real != .download { app.launchArguments += ["-networkStub", "YES"] }
        if real == nil {
            switch JourneyCatalogue.file {
            case .success(let file): app.launchArguments += ["-catalogueFile", file.path]
            case .failure(let error): XCTFail("\(error)")
            }
        }
        app.launchArguments += extra
        return app
    }

    @MainActor
    func launch(_ extra: [String] = JourneyTestCase.quizSeen, real: Real? = nil) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
        let app = Self.application(extra, real: real)
        app.launch()
        return app
    }

    /// A journey that launches while the last one's Loe is still on its way out
    /// fails on a slow simulator, so each one ends with Loe gone.
    override func tearDown() async throws {
        await MainActor.run { Self.quit(XCUIApplication()) }
        try await super.tearDown()
    }

    @MainActor
    static func quit(_ app: XCUIApplication) {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 30))
    }

    /// Picks the newest photo in the system's photo picker, the first in its grid.
    /// The picker can be slow to fill on a busy simulator, so this waits for the
    /// photo itself.
    @MainActor
    func chooseTheNewestPhoto(in app: XCUIApplication) {
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 90), "The photo picker shows no photos")
        photo.tap()
    }

    /// Whether the element shows the plain blue cover that `-networkStub YES` gives
    /// ESTER for „Ave Maria“. A cover is hidden from accessibility, so this looks
    /// at the picture: nothing else on a list is blue.
    @MainActor
    func showsESTERsCover(_ element: XCUIElement) -> Bool {
        guard let image = element.screenshot().image.cgImage else { return false }
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return false }
        var blue = 0
        for pixel in stride(from: 0, to: bytes.count, by: 4)
        where Int(bytes[pixel + 2]) > Int(bytes[pixel]) + 50 && Int(bytes[pixel + 2]) > Int(bytes[pixel + 1]) + 30 {
            blue += 1
        }
        // A cover is a good part of its row. A stray pixel or two is not one.
        return blue * 20 > width * height
    }

    /// A cover fades in, so it is looked for until it is there.
    @MainActor
    func waitForESTERsCover(on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if showsESTERsCover(element) { return true }
            usleep(200_000)
        }
        return showsESTERsCover(element)
    }

    @MainActor
    func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
