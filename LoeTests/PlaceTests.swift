import Foundation
import Testing
@testable import Loe

struct PlaceTests {
    @Test func everyPlaceHasItsOwnID() {
        let ids = Place.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// IDs are kept in the reader's iCloud. Changing one loses the reader's pick.
    @Test func idsStayAsShipped() {
        #expect(Place.withID("ester.tlnrk.kannukuke")?.name == "Kännukuke")
        #expect(Place.withID("ester.tartulr.karlova")?.name == "Karlova-Ropka")
        #expect(Place.withID("ester.tür")?.name == "Tartu Ülikooli Raamatukogu")
        #expect(Place.withID("shop.rahvaraamat")?.name == "Rahva Raamat")
        #expect(Place.withID("shop.apollo")?.kind == .shop)
        #expect(Place.withID("ester.nowhere") == nil)
    }

    // Holdings rows as ESTER showed them for „Kevade“ in November 2026.
    @Test(arguments: [
        ("TlnRK Kännukuke lastekirjandus", "ester.tlnrk.kannukuke"),
        ("TlnRK Männi lastekirjandus", "ester.tlnrk.manni"),
        ("TlnRK Männiku lastekirjandus", "ester.tlnrk.manniku"),
        ("TlnRK Tondi lastekirjandus", "ester.tlnrk.tondi"),
        ("TlnRK Tondiraba miniraamatukogu", "ester.tlnrk.tondiraba"),
        ("TlnRK Väike-Õismäe lastekirjandus", "ester.tlnrk.vaike-oismae"),
        ("TlnRK bussi lastekirjandus", "ester.tlnrk.buss"),
        ("TlnRK buss kojulaenutus", "ester.tlnrk.buss"),
        ("Tartu LR Karlova harukogu (21p)", "ester.tartulr.karlova"),
        ("Tartu LR Tammelinna harukogu (21p)", "ester.tartulr.tammelinna"),
        ("Tartu LR lasteosakond (21p)", "ester.tartulr.peamaja"),
        ("Tartu LR eestik. ilukirjandus 2.korrus (21p)", "ester.tartulr.peamaja"),
        ("RR 2.k hoidla (K)", "ester.rr"),
        ("RaRa Solarise esindus", "ester.rr"),
        ("TÜR arhiivkogu", "ester.tür"),
        ("TLÜAR hoidla (kohalkasutus)", "ester.tlüar"),
        ("KV Paldiski sõjaväelinnaku laenutuspunkt", "ester.kv"),
    ])
    func aHoldingsRowBelongsToTheMostSpecificPlace(location: String, id: String) {
        #expect(Place.library(forLocation: location)?.id == id)
    }

    @Test func aLocationOfNoKnownLibraryBelongsNowhere() {
        #expect(Place.library(forLocation: "Pärnu KRK lastekirjandus") == nil)
        #expect(Place.library(forLocation: "TlnRKX something") == nil)
        // A branch Loe does not know yet, whose name starts like one it does.
        #expect(Place.library(forLocation: "TlnRK Männikuvälja lastekirjandus") == nil)
    }

    @Test func aShopLinksToItsSearchAndALibraryDoesNot() {
        #expect(BookLinks.shop(.apollo, query: "Kevade")?.host() == "www.apollo.ee")
        #expect(BookLinks.shop(.rahvaRaamat, query: "Kevade")?.host() == "www.rahvaraamat.ee")
        #expect(BookLinks.shop(Place.tallinnBranches[0], query: "Kevade") == nil)
    }
}
