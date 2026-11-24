import Foundation
import SQLite3
import Testing
@testable import Loe

struct HeadingNameTests {
    private let estonian = Locale(identifier: "et")
    private let english = Locale(identifier: "en")

    @Test func aCommonGenreHasAnEnglishName() {
        #expect(HeadingName.of("põnevusromaanid", in: english) == "Thriller novels")
        #expect(HeadingName.of("ajaloolised romaanid", in: english) == "Historical novels")
    }

    @Test func estonianShowsTheHeadingItselfWithACapitalLetter() {
        #expect(HeadingName.of("põnevusromaanid", in: estonian) == "Põnevusromaanid")
        #expect(HeadingName.of("õudusjutud", in: estonian) == "Õudusjutud")
    }

    @Test func aHeadingWithNoEnglishNameReadsAsTheBibliographyHasIt() {
        #expect(HeadingName.of("inimese evolutsioon", in: english) == "Inimese evolutsioon")
        #expect(HeadingName.of("inimese evolutsioon", in: estonian) == "Inimese evolutsioon")
        #expect(HeadingName.of("Teine maailmasõda, 1939-1945", in: english) == "Teine maailmasõda, 1939-1945")
    }

    /// A translation that drifted from its heading would give one book two names.
    @Test func everyNamesEstonianIsItsHeading() {
        for heading in HeadingName.names.keys.sorted() {
            #expect(HeadingName.of(heading, in: estonian) == HeadingName.capitalised(heading))
            #expect(HeadingName.of(heading, in: english) != HeadingName.capitalised(heading), "\(heading) has no English name")
        }
    }

    @Test func noHeadingLeftOutOfTheTagsIsNamed() {
        #expect(BookTags.leftOut.isDisjoint(with: HeadingName.names.keys))
    }

    /// Checks the table against the real catalogue where there is one: a misspelt
    /// heading would quietly never get its English name.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: CatalogueStore.defaultURL.path)))
    func everyNamedHeadingIsAGenreInTheInstalledCatalogue() throws {
        var db: OpaquePointer?
        try #require(sqlite3_open_v2(CatalogueStore.defaultURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        try #require(sqlite3_prepare_v2(db, "SELECT name FROM heading WHERE kind = 2", -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var genres: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 0) { genres.insert(String(cString: name)) }
        }
        let unknown = HeadingName.names.keys.filter { !genres.contains($0) }.sorted()
        #expect(unknown.isEmpty, "Not a genre heading in the catalogue: \(unknown)")
    }
}
