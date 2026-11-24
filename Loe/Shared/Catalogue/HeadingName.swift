import Foundation

/// A catalogue heading in the language Loe is showing, which a view reads from its
/// environment. The bibliography writes its headings in Estonian, so Estonian shows
/// the heading itself. The commonest genres have an English name, and any other
/// heading reads as the bibliography has it. See docs/catalogue.md, "Tags".
nonisolated enum HeadingName {
    static func of(_ heading: String, in locale: Locale) -> String {
        capitalised(names[heading].map(locale.localized) ?? heading)
    }

    /// With a capital first letter, as a tag starts.
    static func capitalised(_ heading: String) -> String {
        heading.prefix(1).uppercased() + heading.dropFirst()
    }

    /// Genre headings as the bibliography spells them, each with its English name.
    /// The name's Estonian translation is the heading itself.
    static let names: [String: LocalizedStringResource] = [
        "aforismid": "Aphorisms",
        "aimekirjandus": "Popular science",
        "ajaloolised näidendid": "Historical plays",
        "ajaloolised romaanid": "Historical novels",
        "anekdoodid": "Jokes",
        "antoloogiad": "Anthologies",
        "arenguromaanid": "Coming-of-age novels",
        "armastusluule": "Love poetry",
        "armastusromaanid": "Romance novels",
        "artiklikogumikud": "Collected articles",
        "autobiograafiad": "Autobiographies",
        "biograafiad": "Biographies",
        "biograafilised romaanid": "Biographical novels",
        "dokumentaalkirjandus": "Documentary writing",
        "esseed": "Essays",
        "fantaasiaromaanid": "Fantasy novels",
        "fotoalbumid": "Photo books",
        "haiglaromaanid": "Hospital novels",
        "haikud": "Haiku",
        "humoreskid (kirjandus)": "Humorous sketches",
        "huumor": "Humour",
        "intervjuud": "Interviews",
        "juhendid": "Guides",
        "jutud": "Stories",
        "jutustused": "Tales",
        "kirjad": "Letters",
        "kokaraamatud": "Cookbooks",
        "komöödiad": "Comedies",
        "koolijutud": "School stories",
        "kooliõpikud": "School textbooks",
        "koomiksid": "Comics",
        "kriminaaljutud": "Crime stories",
        "kriminaalromaanid": "Crime novels",
        "kunstialbumid": "Art books",
        "käsiraamatud": "Handbooks",
        "kõrgkooliõpikud": "University textbooks",
        "külaromaanid": "Village novels",
        "lastekirjandus": "Children's books",
        "laulikud": "Songbooks",
        "laulutekstid": "Song lyrics",
        "loomajutud": "Animal stories",
        "luuletused": "Poems",
        "lühiromaanid": "Short novels",
        "mugandused": "Adaptations",
        "muinasjutud": "Fairy tales",
        "mälestused": "Memoirs",
        "noorsookirjandus": "Young adult books",
        "novellid": "Short stories",
        "nuputamisülesanded": "Puzzles",
        "näidendid": "Plays",
        "näitusekataloogid": "Exhibition catalogues",
        "nõuanded": "Advice",
        "perekonnaromaanid": "Family novels",
        "pildiraamatud": "Picture books",
        "poeemid": "Narrative poems",
        "proosaluuletused": "Prose poems",
        "psühholoogilised romaanid": "Psychological novels",
        "päevikromaanid": "Diary novels",
        "päevikud": "Diaries",
        "põnevusromaanid": "Thriller novels",
        "reisijuhid": "Travel guides",
        "reisikirjad": "Travel writing",
        "romaanid": "Novels",
        "rööptekstid": "Parallel texts",
        "satiir": "Satire",
        "satiirilised romaanid": "Satirical novels",
        "seiklusromaanid": "Adventure novels",
        "sonetid": "Sonnets",
        "spiooniromaanid": "Spy novels",
        "sõjaromaanid": "War novels",
        "sõnaraamatud": "Dictionaries",
        "teatmikud": "Reference books",
        "tegelusraamatud": "Activity books",
        "tervisenõuanded": "Health advice",
        "toiduretseptid": "Recipes",
        "töövihikud": "Workbooks",
        "ulmejutud": "Science fiction stories",
        "ulmeromaanid": "Science fiction novels",
        "vaimulik ilukirjandus": "Religious fiction",
        "vigurraamatud": "Novelty books",
        "värssromaanid": "Verse novels",
        "värvimisraamatud": "Colouring books",
        "õpikud": "Textbooks",
        "õppematerjalid": "Study materials",
        "õudusjutud": "Horror stories",
        "õudusromaanid": "Horror novels",
    ]
}
