import SwiftUI
import Testing
@testable import Loe

@MainActor
struct ReadNextSnapshotTests {
    private static func work(_ title: String, by author: String, language: String = "est") -> CatalogueWork {
        let edition = CatalogueEdition(id: 1, erbID: "", title: title, authors: author, language: language)
        return CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
    }

    // One of each reason, and an English favourite, whose title is set in italics.
    private static let suggestions = [
        ReadNextSuggestion(
            work: work("Tõde ja õigus. II jagu", by: "A. H. Tammsaare"),
            reason: .nextInSeries(after: .init(title: "Tõde ja õigus. I jagu", language: "est"))
        ),
        ReadNextSuggestion(work: work("Nukitsamees", by: "Oskar Luts"), reason: .sameAuthor(as: .init(title: "Kevade", language: "est"))),
        ReadNextSuggestion(
            work: work("Agu Sihvka annab aru", by: "Jaan Rannap"),
            reason: .similar(to: [.init(title: "Kevade", language: "est"), .init(title: "Truth and justice", language: "eng")])
        ),
        ReadNextSuggestion(work: work("Wikmani poisid", by: "Jaan Kross"), reason: .similar(to: [.init(title: "Truth and justice", language: "eng")])),
    ]

    @Test(arguments: Snapshot.Look.all)
    func suggestionsWithTheirReasons(look: Snapshot.Look) throws {
        try Snapshot.verify(ReadNextList(suggestions: Self.suggestions) { _ in } wantToRead: { _ in }, named: "read-next", look: look)
    }
}
