import Foundation

/// Where the current catalogue is and how to check it. The app reads
/// tools/catalogue/manifest.json from the repository's main branch.
nonisolated struct CatalogueManifest: Decodable, Equatable, Sendable {
    let version: String
    let schemaVersion: Int
    let url: URL
    let sha256: String
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case version
        case schemaVersion = "schema_version"
        case url
        case sha256
        case size
    }

    init(version: String, schemaVersion: Int, url: URL, sha256: String, size: Int?) {
        self.version = version
        self.schemaVersion = schemaVersion
        self.url = url
        self.sha256 = sha256
        self.size = size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        url = try container.decode(URL.self, forKey: .url)
        sha256 = try container.decode(String.self, forKey: .sha256).lowercased()
        size = try? container.decodeIfPresent(Int.self, forKey: .size)
    }
}
