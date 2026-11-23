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
        guard case .differs("loe-light-en.png", let share) = other else {
            Issue.record("Another text matched the reference: \(other)")
            return
        }
        #expect(share > Snapshot.tolerance)
        #expect(other.problem != nil)
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
