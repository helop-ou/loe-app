import Foundation
import Testing
@testable import Loe

struct AvailabilityTests {
    private static let fixtures = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures")
    /// The day the fixtures were saved.
    private static let today = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 19))!

    private static func page(_ name: String) throws -> String {
        try String(contentsOf: fixtures.appending(path: name), encoding: .utf8)
    }

    private static func copies(_ name: String) throws -> [LibraryCopy] {
        ESTERHoldings.copies(in: try page(name), today: today)
    }

    private static func states(_ copies: [LibraryCopy], at location: String) -> [LibraryCopy.State] {
        copies.filter { $0.location == location }.map(\.state)
    }

    private static func due(_ day: Int, _ month: Int) -> LibraryCopy.State {
        .onLoan(DateComponents(year: 2026, month: month, day: day))
    }

    // MARK: Reading a holdings page

    @Test func readsEveryRowOfARealPage() throws {
        #expect(ESTERHoldings.rows(in: try Self.page("ester-kevade-2025.html")).count == 139)
        #expect(ESTERHoldings.rows(in: try Self.page("ester-tode-ja-oigus-2003.html")).count == 19)
    }

    @Test func copiesOnTheShelfAndOnLoan() throws {
        let copies = try Self.copies("ester-kevade-2025.html")
        #expect(Self.states(copies, at: "TlnRK Kännukuke lastekirjandus") == [.onShelf, Self.due(1, 12), Self.due(11, 11)])
        #expect(Self.states(copies, at: "TlnRK Sõle lastekirjandus") == [.inStorage, Self.due(17, 10), .onShelf, .onShelf, .onShelf])
        #expect(Self.states(copies, at: "TlnRK Väike-Õismäe lastekirjandus").contains(.inTransit))
    }

    @Test func copiesOnlyToReadInTheLibrary() throws {
        let copies = try Self.copies("ester-kevade-2025.html")
        // An archive copy, and one lent for the reading room until a date.
        #expect(Self.states(copies, at: "KMAR eesti raamat") == [.readThere, Self.due(31, 12)])
        #expect(Self.states(copies, at: "TLÜAR hoidla (kohalkasutus)") == [.readThere])
        #expect(Self.states(copies, at: "TÜR arhiivkogu") == [.readThere, .readThere])
    }

    @Test func copiesNoReaderCanGetAreLeftOut() throws {
        let copies = try Self.copies("ester-kevade-2025.html")
        // Packed away for a renovation, and one of two billed as lost.
        #expect(Self.states(copies, at: "RR 3.k arhiivkogu").isEmpty)
        #expect(Self.states(copies, at: "Tartu LR eestik. ilukirjandus 2.korrus (21p)") == [Self.due(7, 12)])
    }

    @Test func aReturnedCopyIsOnTheShelfAndStorageCopiesCanBeOrdered() throws {
        let copies = try Self.copies("ester-tode-ja-oigus-2003.html")
        #expect(Self.states(copies, at: "TlnRK Kännukuke kojulaenutus") == [.onShelf])
        #expect(Self.states(copies, at: "TlnRK Väike-Õismäe kojulaenutus") == [Self.due(3, 12)] + Array(repeating: .inStorage, count: 4))
    }

    @Test(arguments: [
        ("TlnRK Südalinna teatmekogu", "KOHAL", "", LibraryCopy.State.readThere),
        ("TlnRK Südalinna lugemissaal", "KOHAL", "", .readThere),
        ("TLÜAR hoidla (koju)", "KOHAL", "", .inStorage),
        ("TÜR avahoidla (30p)", "KOHAL", "", .onShelf),
        ("TÜR hoidla (telli saali)", "KOHAL", "", .readThere),
        ("TlnRK Nõmme kojulaenutus", "TÄHTAEG 03.12.26 VARUKOGUS", "", .onLoan(DateComponents(year: 2026, month: 12, day: 3))),
        ("KMAR eesti raamat", "KOHAL", "EI LAENUTATA", .readThere),
    ])
    func eachCopyCountsByWhereItIs(location: String, status: String, note: String, state: LibraryCopy.State) {
        #expect(ESTERHoldings.copy(location: location, status: status, note: note, today: Self.today)?.state == state)
    }

    @Test func aCopyLongOverdueIsTakenToBeLost() {
        #expect(ESTERHoldings.copy(location: "TlnRK Nõmme kojulaenutus", status: "TÄHTAEG 20.03.19", note: "", today: Self.today) == nil)
        #expect(ESTERHoldings.copy(location: "TlnRK Nõmme kojulaenutus", status: "TÄHTAEG 11.11.26", note: "", today: Self.today) != nil)
    }

    @Test func theHoldingsPageOfAnEdition() {
        #expect(ESTERHoldings.url(erbID: "b10500820")?.absoluteString
            == "https://www.ester.ee/search*est?/.b1050082/.b1050082/1,1,1,B/holdings~1050082&FF=&1,0,")
        #expect(ESTERHoldings.url(erbID: "b1210534x")?.absoluteString
            == "https://www.ester.ee/search*est?/.b1210534/.b1210534/1,1,1,B/holdings~1210534&FF=&1,0,")
        #expect(ESTERHoldings.url(erbID: "1050082") == nil)
        #expect(ESTERHoldings.url(erbID: "b1050082y") == nil)
    }

    // MARK: A library's row

    private static let kannukuke = Place.withID("ester.tlnrk.kannukuke")!
    private static let nomme = Place.withID("ester.tlnrk.nomme")!
    private static let newer = CatalogueEdition(id: 2, erbID: "b20000002", title: "Kevade", year: 2025)
    private static let older = CatalogueEdition(id: 1, erbID: "b10000001", title: "Kevade", year: 2008)

    private static func availability(
        at place: Place, newer: [LibraryCopy], older: [LibraryCopy] = []
    ) -> LibraryAvailability {
        LibraryAvailability.of(
            place, copies: [Self.newer.erbID: newer, Self.older.erbID: older],
            editions: [Self.newer, Self.older], onScreen: Self.newer.erbID, today: today
        )
    }

    private static func copy(_ location: String, _ state: LibraryCopy.State) -> LibraryCopy {
        LibraryCopy(location: location, state: state)
    }

    @Test func onTheShelfWinsOverEverythingElse() {
        let here = "TlnRK Kännukuke lastekirjandus"
        let state = Self.availability(at: Self.kannukuke, newer: [Self.copy(here, Self.due(1, 12)), Self.copy(here, .inStorage), Self.copy(here, .onShelf)])
        #expect(state == .onShelf)
    }

    @Test func anotherEditionOnTheShelfIsNamed() {
        let state = Self.availability(
            at: Self.nomme,
            newer: [Self.copy("TlnRK Nõmme lastekirjandus", Self.due(1, 12))],
            older: [Self.copy("TlnRK Nõmme lastekirjandus", .onShelf)]
        )
        #expect(state == .otherEditionOnShelf(year: 2008))
    }

    @Test func otherLibrariesCopiesDoNotCount() {
        let state = Self.availability(at: Self.kannukuke, newer: [Self.copy("TlnRK Nõmme lastekirjandus", .onShelf)])
        #expect(state == .notHere)
    }

    @Test func storageBeforeLoansBeforeTransitBeforeReadingThere() {
        let here = "TlnRK Kännukuke lastekirjandus"
        #expect(Self.availability(at: Self.kannukuke, newer: [Self.copy(here, Self.due(1, 12)), Self.copy(here, .inStorage)]) == .inStorage)
        #expect(Self.availability(at: Self.kannukuke, newer: [Self.copy(here, .inTransit), Self.copy(here, Self.due(1, 12))])
            == .onLoan(DateComponents(year: 2026, month: 12, day: 1)))
        #expect(Self.availability(at: Self.kannukuke, newer: [Self.copy(here, .readThere), Self.copy(here, .inTransit)]) == .inTransit)
        #expect(Self.availability(at: Self.kannukuke, newer: [Self.copy("TlnRK Kännukuke teatmekogu", .readThere)]) == .readThere)
    }

    @Test func aLoanShowsTheFirstDayToComeOrSaysOverdue() {
        let here = "TlnRK Kännukuke lastekirjandus"
        #expect(Self.availability(at: Self.kannukuke, newer: [Self.copy(here, Self.due(11, 11)), Self.copy(here, Self.due(7, 12)), Self.copy(here, Self.due(1, 12))])
            == .onLoan(DateComponents(year: 2026, month: 12, day: 1)))
        #expect(Self.availability(at: Self.kannukuke, newer: [Self.copy(here, Self.due(11, 11))]) == .onLoan(nil))
    }

    @Test func aRealPageForTheLibrariesOnIt() throws {
        let copies = try Self.copies("ester-kevade-2025.html")
        let edition = CatalogueEdition(id: 1, erbID: "b52069120", title: "Kevade", year: 2025)
        func at(_ id: String) -> LibraryAvailability {
            LibraryAvailability.of(Place.withID(id)!, copies: [edition.erbID: copies], editions: [edition], onScreen: edition.erbID, today: Self.today)
        }
        #expect(at("ester.tlnrk.kannukuke") == .onShelf)
        #expect(at("ester.tlüar") == .readThere)
        #expect(at("ester.tlnrk.liivalaia") == .notHere)

        let tode = CatalogueEdition(id: 2, erbID: "b18179240", title: "Tõde ja õigus. I", year: 2003)
        let stored = try Self.copies("ester-tode-ja-oigus-2003.html")
        let vaikeOismae = LibraryAvailability.of(
            Place.withID("ester.tlnrk.vaike-oismae")!, copies: [tode.erbID: stored], editions: [tode], onScreen: tode.erbID, today: Self.today
        )
        #expect(vaikeOismae == .inStorage)
    }
}
