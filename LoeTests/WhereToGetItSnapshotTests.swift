import SwiftUI
import Testing
@testable import Loe

@MainActor
struct WhereToGetItSnapshotTests {
    private static let url = URL(string: "https://www.ester.ee/record=b1050082")!

    private static func row(_ name: String, _ status: WhereToGetItCard.Status?) -> WhereToGetItCard.Row {
        .init(id: name, name: name, detail: Text(verbatim: "Tallinna Raamatukogud"), url: url, status: status)
    }

    // Every way a library can answer, and a shop with none.
    private static let rows: [WhereToGetItCard.Row] = [
        row("Kännukuke", .known(.onShelf)),
        row("Pelguranna", .known(.otherEditionOnShelf(year: 2013))),
        row("Sõle", .known(.inStorage)),
        row("Nõmme", .known(.onLoan(DateComponents(year: 2026, month: 12, day: 1)))),
        row("Kalamaja", .known(.onLoan(nil))),
        row("Väike-Õismäe", .known(.inTransit)),
        row("Südalinna", .known(.readThere)),
        row("Pirita", .known(.notHere)),
        row("Laagna", .failed),
        .init(id: "apollo", name: "Apollo", detail: Text("Bookshop"), url: url),
    ]

    @Test(arguments: Snapshot.Look.all)
    func everyAnswerALibraryCanGive(look: Snapshot.Look) throws {
        let card = WhereToGetItCard(rows: Self.rows, namesESTER: true).padding(20)
        try Snapshot.verify(card, named: "where-to-get-it", look: look)
    }
}
