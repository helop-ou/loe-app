import CoreTransferable
import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Loe

/// The reader's shelves as a CSV file. See docs/library.md, "Export".
struct ShelvesExportTests {
    private let context: ModelContext
    private let tallinn = TimeZone(identifier: "Europe/Tallinn")!
    /// Friday 27 November 2026, 12:00 in Tallinn.
    private let noon = Date(timeIntervalSince1970: 1_795_773_600)

    init() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    // What the share sheet does with the row's file: asks it for a CSV, and gets
    // one under the name the sheet showed.
    @Test func theShareSheetIsHandedTheFileUnderTheNameItShows() async throws {
        let books = [ShelvesExport.Book(title: "Tõde ja õigus", authors: "A. H. Tammsaare", added: noon)]
        let file = ShelvesFile(books: books, name: "Loe 2026-11-27.csv")
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let exported = try await file.export(to: folder, contentType: .commaSeparatedText)

        #expect(exported.lastPathComponent == "Loe 2026-11-27.csv")
        #expect(try String(contentsOf: exported, encoding: .utf8).contains("Tõde ja õigus,A. H. Tammsaare"))
        // Left to itself it is named for today.
        #expect(ShelvesFile(books: books).name == ShelvesExport.fileName())
    }

    /// The file's lines without the mark at its start, split as it ends them.
    private func lines(_ books: [ShelvesExport.Book]) -> [String] {
        let csv = ShelvesExport.csv(of: books, timeZone: tallinn)
        return csv.dropFirst().components(separatedBy: "\r\n")
    }

    // A file exported today has to read back, into Loe or anything that reads a
    // Goodreads export, so the columns never move.
    @Test func theColumnsAreTheseInThisOrder() {
        #expect(lines([])[0] == """
            Title,Author,Additional Authors,ISBN13,My Rating,Number of Pages,Year Published,Date Read,Date Added,\
            Exclusive Shelf,Subtitle,Language,Date Started,Current Page,Source,ESTER Record,Open Library Key
            """)
        #expect(ShelvesExport.columns.count == 17)
    }

    @Test func theFileStartsWithAByteOrderMarkAndEveryLineEndsTheSameWay() {
        let csv = ShelvesExport.csv(of: [ShelvesExport.Book(title: "Kevade", added: noon)], timeZone: tallinn)
        #expect(csv.unicodeScalars.first == "\u{FEFF}")
        #expect(csv.hasSuffix("\r\n"))
        #expect(csv.components(separatedBy: "\r\n").count == 3)
        #expect(!csv.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
        // Every row has a field for every column.
        #expect(lines([ShelvesExport.Book(title: "Kevade", added: noon)])[1].split(separator: ",", omittingEmptySubsequences: false).count == 17)
    }

    // A book from the catalogue, one from Open Library and one entered by hand,
    // shelved as the app shelves them.
    @Test func aMixedLibraryKeepsEveryBookWithItsDetails() throws {
        let kross = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", subtitle: "romaan", authors: "Jaan Kross", pages: 352)
        let catalogued = try ShelvedBook.shelve(
            CatalogueWork(id: CatalogueWork.key(for: kross), editions: [kross]), edition: kross, on: .reading, in: context,
            now: noon.addingTimeInterval(-3 * 86_400)
        )
        catalogued.currentPage = 212
        let halo = OpenLibraryBook(
            record: OpenLibraryRecord(workKey: "/works/OL18626W", isbn: "9780345451323", coverID: 210_551),
            title: "Halo: The Fall of Reach", authors: ["Eric S. Nylund", "Someone Else"], year: 2001, pages: 339, language: "eng"
        ).work
        let abroad = try ShelvedBook.shelve(halo, edition: halo.editions[0], on: .reading, in: context, now: noon.addingTimeInterval(-2 * 86_400))
        abroad.move(to: .read, now: noon)
        abroad.rating = 4
        let byHand = ShelvedBook.add(
            EnteredBook(title: "Recipes, mostly", authors: "A. Cook", pages: 80, year: 1999, language: "eng"),
            on: .wantToRead, in: context, now: noon.addingTimeInterval(-86_400)
        )

        let rows = lines([byHand, abroad, catalogued].map(ShelvesExport.Book.init))

        #expect(rows.count == 5)
        #expect(rows[1] == "Keisri hull,Jaan Kross,,,,352,,,2026/11/24,currently-reading,romaan,,2026/11/24,212,catalogue,b10544215,")
        #expect(rows[2] == """
            Halo: The Fall of Reach,Eric S. Nylund,Someone Else,"=""9780345451323\""",4,339,2001,2026/11/27,2026/11/25,read,,eng,\
            2026/11/25,339,openLibrary,,/works/OL18626W
            """)
        #expect(rows[3] == "\"Recipes, mostly\",A. Cook,,,,80,1999,,2026/11/26,to-read,,eng,,,hand,,")
        #expect(rows[4].isEmpty)
    }

    @Test func aFieldWithACommaAQuoteOrALineBreakIsQuoted() {
        #expect(ShelvesExport.field("Tõde ja õigus") == "Tõde ja õigus")
        #expect(ShelvesExport.field("Rehepapp, ehk, November") == "\"Rehepapp, ehk, November\"")
        #expect(ShelvesExport.field("The \"Good\" Book") == "\"The \"\"Good\"\" Book\"")
        #expect(ShelvesExport.field("Two\nlines") == "\"Two\nlines\"")
        #expect(ShelvesExport.field("Two\r\nlines") == "\"Two\r\nlines\"")
        #expect(ShelvesExport.field("Two\rlines") == "\"Two\rlines\"")
        #expect(ShelvesExport.field("") == "")
    }

    // A title comes from a catalogue or from Open Library, and a spreadsheet runs
    // a cell that starts like a formula.
    @Test(arguments: ["=HYPERLINK(\"https://loe.test\")", "+1", "-1", "@work", "\tTabbed", "\rReturned"])
    func textThatWouldRunAsAFormulaIsMadePlain(title: String) throws {
        #expect(ShelvesExport.text(title) == "'" + title)
        let book = ShelvesExport.Book(title: title, subtitle: title, authors: "\(title); \(title)", added: noon, erbID: title, openLibraryKey: title)
        let row = ShelvesExport.row(for: book, timeZone: tallinn)
        // Whatever the column made of it, no text column starts a formula.
        for column in [0, 1, 2, 10, 15, 16] {
            let written = row[column].hasPrefix("\"") ? row[column].dropFirst() : row[column][...]
            let first = try #require(written.unicodeScalars.first)
            #expect(!"=+-@\t\r".unicodeScalars.contains(first), "column \(column) is \(row[column])")
        }
        #expect(row[0].contains("'" + title.prefix(1)))
    }

    @Test func plainTextIsLeftAsItIs() {
        #expect(ShelvesExport.text("Tõde ja õigus") == "Tõde ja õigus")
        #expect(ShelvesExport.text("1984") == "1984")
        #expect(ShelvesExport.text("") == "")
    }

    // Thirteen digits show as 9.78E+12 in a spreadsheet unless they are written
    // the way Goodreads writes them. Nothing but an ISBN is ever written so.
    @Test func anISBNIsWrittenSoASpreadsheetKeepsItsDigits() {
        #expect(ShelvesExport.digits("9780345451323") == "=\"9780345451323\"")
        #expect(ShelvesExport.digits("034545132X") == "=\"034545132X\"")
        #expect(ShelvesExport.digits(nil) == "")
        #expect(ShelvesExport.digits("") == "")
        #expect(ShelvesExport.digits("9780345451323\"&HYPERLINK(\"https://loe.test\")") == "")
        #expect(ShelvesExport.digits("978-0-345") == "")
    }

    @Test func everyShelfHasAWordOfItsOwn() {
        #expect(Shelf.allCases.map(ShelvesExport.name(of:)) == ["currently-reading", "to-read", "read", "set-aside", "did-not-finish"])
    }

    // A day is the reader's own, so a book finished late in the evening is not
    // written under the next day, or the day before.
    @Test func aDayIsTheDayWhereTheReaderIs() {
        let lateEvening = noon.addingTimeInterval(11.5 * 3600)
        #expect(ShelvesExport.day(lateEvening, in: tallinn) == "2026/11/27")
        #expect(ShelvesExport.day(lateEvening, in: TimeZone(identifier: "Asia/Tokyo")!) == "2026/11/28")
        #expect(ShelvesExport.day(Date(timeIntervalSince1970: 0), in: TimeZone(identifier: "UTC")!) == "1970/01/01")
    }

    @Test func booksAreInTheOrderTheyWereAdded() {
        let books = [
            ShelvesExport.Book(title: "Third", added: noon),
            ShelvesExport.Book(title: "Second B", added: noon.addingTimeInterval(-60)),
            ShelvesExport.Book(title: "Second A", added: noon.addingTimeInterval(-60)),
            ShelvesExport.Book(title: "First", added: noon.addingTimeInterval(-3600)),
        ]
        #expect(lines(books).dropFirst().dropLast().map { $0.split(separator: ",")[0] } == ["First", "Second A", "Second B", "Third"])
    }

    @Test func theFileIsNamedForTheDayItWasMade() {
        #expect(ShelvesExport.fileName(on: noon, timeZone: tallinn) == "Loe 2026-11-27.csv")
    }

    // What the share sheet is handed: UTF-8 with its mark, under the name it was given.
    @Test func theFileOnDiskIsUTF8UnderItsOwnName() throws {
        let parent = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let books = [ShelvesExport.Book(title: "Tõde ja õigus", authors: "A. H. Tammsaare", added: noon)]

        let file = try ShelvesExport.write(books, named: "Loe 2026-11-27.csv", in: parent)
        let other = try ShelvesExport.write(books, named: "Loe 2026-11-27.csv", in: parent)

        #expect(file.lastPathComponent == "Loe 2026-11-27.csv")
        #expect(file != other)
        let data = try Data(contentsOf: file)
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(decoding: data, as: UTF8.self).contains("Tõde ja õigus,A. H. Tammsaare"))
    }
}
