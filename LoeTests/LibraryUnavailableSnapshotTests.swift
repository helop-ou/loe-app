import SwiftUI
import Testing
@testable import Loe

@MainActor
struct LibraryUnavailableSnapshotTests {
    @Test(arguments: Snapshot.Look.all)
    func theScreenForALibraryThatCannotBeOpened(look: Snapshot.Look) throws {
        try Snapshot.verify(LibraryUnavailableView {}, named: "library-unavailable", look: look)
    }
}
