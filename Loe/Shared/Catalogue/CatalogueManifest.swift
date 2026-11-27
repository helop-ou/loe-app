import Foundation

/// A catalogue that is published: where it is and how to check it.
nonisolated struct PublishedCatalogue: Decodable, Equatable, Sendable {
    let version: String
    let schemaVersion: Int
    let url: URL
    let sha256: String
    let size: Int?
    /// How many editions it holds, which the unpacked file is held to.
    let editions: Int?

    enum CodingKeys: String, CodingKey {
        case version
        case schemaVersion = "schema_version"
        case url
        case sha256
        case size
        case editions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        url = try container.decode(URL.self, forKey: .url)
        sha256 = try container.decode(String.self, forKey: .sha256).lowercased()
        size = try? container.decodeIfPresent(Int.self, forKey: .size)
        editions = try? container.decodeIfPresent(Int.self, forKey: .editions)
    }
}

/// The catalogues that are published, one for each schema, so a build of any age
/// finds the one it can read. The app reads tools/catalogue/manifest.json from the
/// repository's main branch. See docs/catalogue.md, "Download and updates".
nonisolated struct CatalogueManifest: Decodable, Equatable, Sendable {
    /// One catalogue as the manifest lists it. Only its schema has to be readable,
    /// since a catalogue for a newer Loe may be described in a way this build
    /// does not know.
    private struct Listed: Decodable, Equatable {
        let schemaVersion: Int
        let catalogue: PublishedCatalogue?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: PublishedCatalogue.CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            catalogue = try? PublishedCatalogue(from: decoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case catalogues
        case asksESTER = "asks_ester"
    }

    private let listed: [Listed]
    /// False when the manifest turns off everything Loe asks ESTER. Anything but
    /// a plain `true` there is a no, so a slip in the file can only make Loe ask
    /// less. See docs/library.md, "Turning ESTER off".
    let asksESTER: Bool

    /// The file's top level is a catalogue itself, the only one the first builds
    /// read. The catalogues of later schemas are listed under it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let first = try Listed(from: decoder)
        listed = try [first] + (container.decodeIfPresent([Listed].self, forKey: .catalogues) ?? [])
        asksESTER = !container.contains(.asksESTER) || (try? container.decode(Bool.self, forKey: .asksESTER)) == true
    }

    /// The catalogue a build that reads `schema` installs.
    func catalogue(forSchema schema: Int) -> PublishedCatalogue? {
        listed.first { $0.schemaVersion == schema }?.catalogue
    }

    /// Whether there is a catalogue that only a newer Loe can read.
    func hasCatalogue(newerThanSchema schema: Int) -> Bool {
        listed.contains { $0.schemaVersion > schema }
    }

    /// The month an edition was built in, from a version such as "2026-11".
    static func month(ofVersion version: String) -> Date? {
        let parts = version.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month) else {
            return nil
        }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: 15))
    }
}
