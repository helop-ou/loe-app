import SwiftUI
import Testing
@testable import Loe

@MainActor
struct ScanHintSnapshotTests {
    @Test(arguments: Snapshot.Look.all)
    func eachHintTheScannerShows(look: Snapshot.Look) throws {
        // Over a dark grey, as over the camera.
        let hints = VStack(spacing: 16) {
            ScanHint(other: nil)
            ScanHint(other: .library)
            ScanHint(other: .notABook)
        }
        .padding(24)
        .background(Color(white: 0.3))
        try Snapshot.verify(hints, named: "scan-hint", look: look)
    }
}
