import Foundation
import SQLite3

/// The small catalogue the journeys search, so they find the same books on every
/// simulator: the real schema from tools/catalogue filled with the records in
/// Fixtures/catalogue.sql. Built once for a run.
enum JourneyCatalogue {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static let file = Result { try build() }

    private static func build() throws -> URL {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let schema = try String(contentsOf: root.appending(path: "tools/catalogue/schema.sql"), encoding: .utf8)
        let records = try String(contentsOf: root.appending(path: "LoeUITests/Fixtures/catalogue.sql"), encoding: .utf8)
        let url = URL.temporaryDirectory.appending(path: "journey-catalogue-\(UUID().uuidString).sqlite")
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        guard sqlite3_open(url.path, &database) == SQLITE_OK,
              sqlite3_exec(database, schema + records, nil, nil, nil) == SQLITE_OK
        else {
            throw Failure(description: "The journeys' catalogue could not be built: " + String(cString: sqlite3_errmsg(database)))
        }
        return url
    }
}
