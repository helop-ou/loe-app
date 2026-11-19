import SwiftUI
import Testing
@testable import Loe

@MainActor
struct TasteQuizSnapshotTests {
    @Test(arguments: Snapshot.Look.all)
    func theQuizWithTwoGenresPicked(look: Snapshot.Look) throws {
        let quiz = TasteQuizContent(selection: .constant([.crime, .fantasy]))
        try Snapshot.verify(quiz, named: "taste-quiz", look: look)
    }
}
