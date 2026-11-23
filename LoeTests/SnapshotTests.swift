import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Loe

@MainActor
struct SnapshotTests {
    private static func folder() -> URL {
        URL.temporaryDirectory.appending(path: "iOS-0.0-\(UUID().uuidString)")
    }

    private static func outcome(of text: String, in folder: URL, rendersOnly: Bool = false) throws -> Snapshot.Outcome {
        try Snapshot.outcome(of: Text(verbatim: text), named: "loe", look: Snapshot.Look.all[0], in: folder, rendersOnly: rendersOnly)
    }

    /// A white image with a grey square in its top corner.
    private static func image(width: Int = 804, height: Int, square: Int = 0, grey: CGFloat = 0) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: grey, green: grey, blue: grey, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: square, height: square))
        return try #require(context.makeImage())
    }

    @Test func aRunOnAnIOSWithoutReferencesFailsAndSaysHowToRecordThem() throws {
        let folder = Self.folder()
        let outcome = try Self.outcome(of: "Loe", in: folder)
        #expect(outcome == .noReferences(folder: folder.lastPathComponent))
        let problem = try #require(outcome.problem)
        #expect(problem.contains(folder.lastPathComponent))
        #expect(problem.contains("TEST_RUNNER_LOE_SNAPSHOTS_RENDER_ONLY=1"))
    }

    @Test func aRunThatAskedToOnlyRenderPassesWithoutReferences() throws {
        let folder = Self.folder()
        let outcome = try Self.outcome(of: "Loe", in: folder, rendersOnly: true)
        #expect(outcome == .renderedOnly)
        #expect(outcome.problem == nil)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test func aMissingReferenceIsRecordedAndFailsOnceThenIsComparedWith() throws {
        let folder = Self.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let first = try Self.outcome(of: "Loe", in: folder)
        #expect(first == .recorded("loe-light-en.png"))
        #expect(first.problem != nil)
        #expect(try Self.outcome(of: "Loe", in: folder) == .matches)
        // Asking to only render changes nothing where there are references.
        let other = try Self.outcome(of: "Loen", in: folder, rendersOnly: true)
        guard case .differs("loe-light-en.png", let pixels) = other else {
            Issue.record("Another text matched the reference: \(other)")
            return
        }
        #expect(pixels > Snapshot.budget)
        #expect(other.problem != nil)
    }

    /// The tallest snapshot is some 5,500 pixels high, and a status icon about 22 across.
    @Test func anIconsWorthOfChangeIsOverTheBudgetOnTheTallestSnapshot() throws {
        let differing = try #require(Snapshot.differingPixels(
            Self.image(height: 5500), Self.image(height: 5500, square: 22)
        ))
        #expect(differing == 22 * 22)
        #expect(differing > Snapshot.budget)
    }

    @Test func aShadeApartIsNotADifferenceAndMoreIs() throws {
        let white = try Self.image(height: 100)
        let shade = try Self.image(height: 100, square: 50, grey: 247 / 255)
        let darker = try Self.image(height: 100, square: 50, grey: 246 / 255)
        #expect(Snapshot.differingPixels(white, white) == 0)
        #expect(Snapshot.differingPixels(white, shade) == 0)
        #expect(Snapshot.differingPixels(white, darker) == 50 * 50)
    }

    @Test func imagesOfDifferentSizesDifferEverywhere() throws {
        let differing = try #require(Snapshot.differingPixels(Self.image(height: 100), Self.image(height: 101)))
        #expect(differing == 804 * 101)
    }

    /// What a shelf's row of covers is made of.
    private static var sideways: some View {
        ScrollView(.horizontal) {
            Color.black.frame(width: 100, height: 100)
        }
    }

    @Test func aWindowDrawsWhatScrollsSidewaysAndTheRendererLeavesItOut() throws {
        let folder = Self.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let look = Snapshot.Look.all[0]
        func outcome(on canvas: Snapshot.Canvas) throws -> Snapshot.Outcome {
            try Snapshot.outcome(of: Self.sideways, named: "sideways", look: look, on: canvas, in: folder, rendersOnly: false)
        }
        #expect(try outcome(on: .window) == .recorded("sideways-light-en.png"))
        #expect(try outcome(on: .window) == .matches)
        guard case .differs(_, let pixels) = try outcome(on: .renderer) else {
            Issue.record("The renderer drew what scrolls sideways")
            return
        }
        // The black square, at two pixels to a point.
        #expect(pixels == 200 * 200)
    }

    @Test func aRenderThatFailsIsTriedAgain() {
        var goes = 0
        let value = Snapshot.firstSuccess(in: 3) {
            goes += 1
            return goes < 3 ? nil : "rendered"
        }
        #expect(value == "rendered")
        #expect(goes == 3)
    }

    @Test func aRenderThatWorksIsNotRepeated() {
        var goes = 0
        let value = Snapshot.firstSuccess(in: 3) {
            goes += 1
            return "rendered"
        }
        #expect(value == "rendered")
        #expect(goes == 1)
    }

    @Test func aRenderThatNeverWorksGivesUp() {
        var goes = 0
        let value: String? = Snapshot.firstSuccess(in: 3) {
            goes += 1
            return nil
        }
        #expect(value == nil)
        #expect(goes == 3)
    }
}
