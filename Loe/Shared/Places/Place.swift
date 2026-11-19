import Foundation

/// A library or bookshop the reader can pick for a book's "Where to get it". See
/// docs/library.md, "Where to get it".
nonisolated struct Place: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case library
        case shop
    }

    /// Kept in the reader's iCloud, so never change one.
    let id: String
    /// As the library or shop names itself, in Estonian.
    let name: String
    /// The library a branch belongs to, or nil for a library or shop on its own.
    let group: String?
    let kind: Kind
    /// How ESTER's holdings name this place's shelves. The longest prefix that
    /// matches a holdings row decides its place, so a branch wins over its library.
    let locationPrefixes: [String]

    init(id: String, name: String, group: String? = nil, kind: Kind = .library, locationPrefixes: [String] = []) {
        self.id = id
        self.name = name
        self.group = group
        self.kind = kind
        self.locationPrefixes = locationPrefixes
    }
}

nonisolated extension Place {
    static let rahvaRaamat = Place(id: "shop.rahvaraamat", name: "Rahva Raamat", kind: .shop)
    static let apollo = Place(id: "shop.apollo", name: "Apollo", kind: .shop)

    static let shops = [rahvaRaamat, apollo]

    static let tallinn = "Tallinna Raamatukogud"
    static let tartu = "Tartu Linnaraamatukogu"

    /// Tallinn's branches, as tallinnaraamatukogud.ee/asukohad lists them.
    static let tallinnBranches: [Place] = [
        ("sudalinna", "Südalinna"), ("liivalaia", "Liivalaia"), ("kadrioru", "Kadrioru"), ("kalamaja", "Kalamaja"),
        ("kannukuke", "Kännukuke"), ("laagna", "Laagna"), ("manni", "Männi"), ("manniku", "Männiku"),
        ("nurmenuku", "Nurmenuku"), ("nomme", "Nõmme"), ("paepealse", "Paepealse"), ("pelguranna", "Pelguranna"),
        ("pirita", "Pirita"), ("paaskula", "Pääsküla"), ("sole", "Sõle"), ("saase", "Sääse"), ("tondi", "Tondi"),
        ("torupilli", "Torupilli"), ("vaike-oismae", "Väike-Õismäe"), ("tondiraba", "Tondiraba"),
        ("rocca-al-mare", "Rocca al Mare"), ("ulemiste", "Ülemiste"),
    ].map { Place(id: "ester.tlnrk.\($0.0)", name: $0.1, group: tallinn, locationPrefixes: ["TlnRK \($0.1) "]) }
        // The bus is "buss" on the library's site and "bussi" in ESTER.
        + [Place(id: "ester.tlnrk.buss", name: "Raamatukogubuss", group: tallinn, locationPrefixes: ["TlnRK bus"])]

    /// Tartu's main library, whose shelves ESTER names by department, and its branches.
    static let tartuBranches: [Place] = [
        Place(id: "ester.tartulr.peamaja", name: "Peamaja", group: tartu, locationPrefixes: ["Tartu LR "]),
        Place(id: "ester.tartulr.annelinna", name: "Annelinna", group: tartu, locationPrefixes: ["Tartu LR Annelinna"]),
        Place(id: "ester.tartulr.ilmatsalu", name: "Ilmatsalu", group: tartu, locationPrefixes: ["Tartu LR Ilmatsalu"]),
        Place(id: "ester.tartulr.karlova", name: "Karlova-Ropka", group: tartu, locationPrefixes: ["Tartu LR Karlova"]),
        Place(id: "ester.tartulr.tammelinna", name: "Tammelinna", group: tartu, locationPrefixes: ["Tartu LR Tammelinna"]),
    ]

    /// The other libraries in ESTER, from ELNET's list of participating libraries.
    /// Each is one place, named by its ESTER sigel.
    static let otherLibraries: [Place] = [
        ("APK", "Arvo Pärdi Keskuse raamatukogu"),
        ("BDC", "Balti Kaitsekolledži raamatukogu"),
        ("SAAM", "Eesti Ajaloomuuseumi raamatukogu"),
        ("KMAR", "Eesti Kirjandusmuuseumi Arhiivraamatukogu"),
        ("EKAR", "Eesti Kunstiakadeemia raamatukogu"),
        ("EKMR", "Eesti Kunstimuuseumi raamatukogu"),
        ("LUS", "Eesti Looduseuurijate Seltsi raamatukogu"),
        ("EMÜR", "Eesti Maaülikooli raamatukogu"),
        ("EMTAR", "Eesti Muusika- ja Teatriakadeemia raamatukogu"),
        ("EPR", "Eesti Panga raamatukogu"),
        ("ERM", "Eesti Rahva Muuseumi raamatukogu"),
        ("RR", "Eesti Rahvusraamatukogu"),
        ("ETL", "Eesti Teatriliidu raamatukogu"),
        ("EKS", "Emakeele Seltsi raamatukogu"),
        ("FUAR", "Fenno-Ugria Asutuse raamatukogu"),
        ("KV", "Kaitseväe raamatukogu"),
        ("RA", "Rahvusarhiivi raamatukogud"),
        ("SKA", "Sisekaitseakadeemia raamatukogu"),
        ("SI", "Soome Instituudi raamatukogu"),
        ("TBA", "Tallinna Botaanikaaia raamatukogu"),
        ("TLA", "Tallinna Linnaarhiivi raamatukogu"),
        ("TLM", "Tallinna Linnamuuseumi raamatukogu"),
        ("ZOO", "Tallinna Loomaia raamatukogu"),
        ("TTKR", "Tallinna Tehnikakõrgkooli raamatukogu"),
        ("TalTech", "Tallinna Tehnikaülikooli raamatukogu"),
        ("TTHK", "Tallinna Tervishoiu Kõrgkooli raamatukogu"),
        ("TLÜAR", "Tallinna Ülikooli Akadeemiline Raamatukogu"),
        ("T2MK", "Tartu II Muusikakool"),
        ("TKM", "Tartu Kunstimuuseumi raamatukogu"),
        ("Pallas", "Tartu Kõrgema Kunstikooli Pallas raamatukogu"),
        ("TÜR", "Tartu Ülikooli Raamatukogu"),
    ].map { sigel, name in
        // The National Library's shelves are "RR …", and its Solaris branch "RaRa …".
        let prefixes = sigel == "RR" ? ["RR ", "RaRa "] : ["\(sigel) "]
        return Place(id: "ester.\(sigel.lowercased())", name: name, locationPrefixes: prefixes)
    }

    static let libraries = tallinnBranches + tartuBranches + otherLibraries

    static let all = libraries + shops

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Nil for a place a newer version of Loe added, or one since removed.
    static func withID(_ id: String) -> Place? {
        byID[id]
    }

    /// The place an ESTER holdings row belongs to, by the longest matching prefix.
    static func library(forLocation location: String) -> Place? {
        libraries
            .flatMap { place in place.locationPrefixes.filter(location.hasPrefix).map { (place, $0.count) } }
            .max { $0.1 < $1.1 }?
            .0
    }
}
