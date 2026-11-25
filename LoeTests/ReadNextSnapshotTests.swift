import SwiftUI
import Testing
@testable import Loe

@MainActor
struct ReadNextSnapshotTests {
    private static func work(_ title: String, by author: String, language: String = "est", erbID: String = "") -> CatalogueWork {
        let edition = CatalogueEdition(id: 1, erbID: erbID, title: title, authors: author, language: language)
        return CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
    }

    // One of each reason, and an English favourite, whose title is set in italics.
    // The first two have records, which no other test has a picture for, and the
    // phone has their covers. The others show their cards.
    private static let suggestions = [
        ReadNextSuggestion(
            work: work("Tõde ja õigus. II jagu", by: "A. H. Tammsaare", erbID: "b90010011"),
            reason: .nextInSeries(after: .init(title: "Tõde ja õigus. I jagu", language: "est"))
        ),
        ReadNextSuggestion(
            work: work("Nukitsamees", by: "Oskar Luts", erbID: "b90010021"), reason: .sameAuthor(as: .init(title: "Kevade", language: "est"))
        ),
        ReadNextSuggestion(
            work: work("Agu Sihvka annab aru", by: "Jaan Rannap"),
            reason: .similar(to: [.init(title: "Kevade", language: "est"), .init(title: "Truth and justice", language: "eng")])
        ),
        ReadNextSuggestion(work: work("Wikmani poisid", by: "Jaan Kross"), reason: .similar(to: [.init(title: "Truth and justice", language: "eng")])),
    ]

    @Test(arguments: Snapshot.Look.all)
    func suggestionsWithTheirReasons(look: Snapshot.Look) async throws {
        // The first suggestion's cover is larger than the others'.
        let colours = [
            (UIColor(red: 0.13, green: 0.3, blue: 0.26, alpha: 1), UIColor(red: 0.2, green: 0.45, blue: 0.38, alpha: 1)),
            (UIColor(red: 0.55, green: 0.24, blue: 0.2, alpha: 1), UIColor(red: 0.72, green: 0.36, blue: 0.27, alpha: 1)),
        ]
        for (index, width) in [CGFloat(112), 72].enumerated() {
            let art = try #require(ListedCover.art(for: Self.suggestions[index].work))
            let cover = EPIKTests.picture(width: 160, height: 240, left: colours[index].0, right: colours[index].1)
            _ = try #require(await CoverPictures.shared.picture(of: cover, for: art, width: width, scale: 2))
        }
        try Snapshot.verify(ReadNextList(suggestions: Self.suggestions) { _ in } wantToRead: { _ in }, named: "read-next", look: look)
    }
}
