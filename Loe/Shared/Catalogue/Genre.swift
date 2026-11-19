import Foundation

/// A kind of book the reader can say they like, and the catalogue's genre headings
/// that find it. See docs/catalogue.md, "Genres".
nonisolated enum Genre: String, CaseIterable, Codable, Sendable {
    case crime
    case thriller
    case psychological
    case romance
    case drama
    case historical
    case fantasy
    case scienceFiction
    case horror
    case humour
    case poetry
    case youngAdult

    var name: LocalizedStringResource {
        switch self {
        case .crime: "Crime and mystery"
        case .thriller: "Thrillers"
        case .psychological: "Psychological"
        case .romance: "Romance"
        case .drama: "Family and drama"
        case .historical: "Historical"
        case .fantasy: "Fantasy"
        case .scienceFiction: "Science fiction"
        case .horror: "Horror"
        case .humour: "Humour"
        case .poetry: "Poetry"
        case .youngAdult: "Young adult"
        }
    }

    /// Heading names as the bibliography spells them. Plot twists and mysteries have
    /// no heading of their own: psychological novels are mostly psychological
    /// thrillers, and mysteries are catalogued as crime.
    var headings: [String] {
        switch self {
        case .crime: ["kriminaalromaanid", "kriminaaljutud"]
        case .thriller: ["põnevusromaanid", "spiooniromaanid"]
        case .psychological: ["psühholoogilised romaanid"]
        case .romance: ["armastusromaanid", "haiglaromaanid"]
        case .drama: ["perekonnaromaanid", "päevikromaanid", "arenguromaanid", "külaromaanid"]
        case .historical: ["ajaloolised romaanid", "biograafilised romaanid", "sõjaromaanid", "ajaloolised näidendid"]
        case .fantasy: ["fantaasiaromaanid", "fantaasiakirjandus"]
        case .scienceFiction: ["ulmeromaanid", "ulmejutud", "ulmekirjandus", "düstoopiad"]
        case .horror: ["õudusromaanid", "õudusjutud"]
        case .humour: ["huumor", "humoreskid (kirjandus)", "satiirilised romaanid", "satiir"]
        case .poetry: ["luuletused", "poeemid", "haikud", "proosaluuletused", "sonetid", "armastusluule", "värssromaanid"]
        case .youngAdult: ["noorsookirjandus", "koolijutud"]
        }
    }
}
