import Foundation
import Synchronization
import Testing
@testable import Loe

struct AvailabilityCheckerTests {
    /// Answers with a page holding one copy at Kännukuke, and counts what was asked.
    private actor Server {
        var asked: [URL] = []
        var failing: Set<String> = []

        func answer(_ url: URL) throws -> String {
            asked.append(url)
            if failing.contains(where: url.absoluteString.contains) { throw URLError(.notConnectedToInternet) }
            return """
                <table class="bibItems"><tr class="bibItemsEntry">
                <td><!-- field 1 -->&nbsp;TlnRK Kännukuke lastekirjandus</td>
                <td><!-- field C -->&nbsp;L E/LUT</td>
                <td><!-- field % -->&nbsp;KOHAL </td>
                <td><!-- field ! -->&nbsp;<!-- field n --></td></tr></table>
                """
        }

        func fail(_ record: String) { failing.insert(record) }
    }

    private static func editions(_ count: Int) -> [CatalogueEdition] {
        (1...count).map { CatalogueEdition(id: $0, erbID: String(format: "b1%06d0", $0), title: "Kevade") }
    }

    @Test func asksAboutEachEditionAndReadsItsCopies() async throws {
        let server = Server()
        let checker = AvailabilityChecker { try await server.answer($0) }
        let copies = try #require(await checker.copies(of: Self.editions(2)))
        #expect(copies.count == 2)
        #expect(copies.values.allSatisfy { $0.map(\.state) == [.onShelf] })
        #expect(await server.asked.count == 2)
    }

    @Test func asksAboutTheNewestTwelveOnly() async {
        let server = Server()
        let checker = AvailabilityChecker { try await server.answer($0) }
        let copies = await checker.copies(of: Self.editions(30))
        #expect(copies?.count == 12)
        #expect(await server.asked.count == 12)
        #expect(copies?["b10000010"] != nil)
        #expect(copies?["b10000130"] == nil)
    }

    @Test func reusesAnAnswerForTenMinutes() async {
        let server = Server()
        let clock = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
        let checker = AvailabilityChecker(now: { clock.withLock { $0 } }) { try await server.answer($0) }
        _ = await checker.copies(of: Self.editions(1))
        clock.withLock { $0 += 9 * 60 }
        _ = await checker.copies(of: Self.editions(1))
        #expect(await server.asked.count == 1)
        clock.withLock { $0 += 2 * 60 }
        _ = await checker.copies(of: Self.editions(1))
        #expect(await server.asked.count == 2)
    }

    @Test func anEditionThatFailsIsLeftOutAndNothingAtAllIsNil() async {
        let server = Server()
        await server.fail("b1000002")
        let checker = AvailabilityChecker { try await server.answer($0) }
        let some = await checker.copies(of: Self.editions(2))
        #expect(some?.keys.sorted() == ["b10000010"])

        await server.fail("b1000001")
        let other = AvailabilityChecker { try await server.answer($0) }
        #expect(await other.copies(of: Self.editions(2)) == nil)
    }

    @Test func editionsWithoutARecordAreNotAskedAbout() async {
        let server = Server()
        let checker = AvailabilityChecker { try await server.answer($0) }
        #expect(await checker.copies(of: [CatalogueEdition(id: 0, erbID: "", title: "Kevade")]) == nil)
        #expect(await server.asked.isEmpty)
    }
}
