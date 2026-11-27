import Foundation

/// The reader's shelves as one CSV file, a row for each book, made on the phone.
/// The columns Goodreads also has carry its names and its way of writing them, so
/// a tool that reads a Goodreads export reads this, and Loe's own columns follow
/// them. See docs/library.md, "Export".
nonisolated enum ShelvesExport {
    /// One shelved book, as much of it as the file keeps.
    struct Book: Equatable, Sendable {
        var title = ""
        var subtitle: String?
        /// As the shelves keep them, several separated by "; ".
        var authors: String?
        var isbn: String?
        var rating: Int?
        var pages: Int?
        var currentPage: Int?
        var year: Int?
        var language: String?
        var shelf = Shelf.wantToRead
        var added = Date.now
        var started: Date?
        var finished: Date?
        var source = ShelvedBook.Source.catalogue
        var erbID = ""
        var openLibraryKey: String?
    }

    /// Never rename or reorder these: a file exported today has to read back.
    static let columns = [
        "Title", "Author", "Additional Authors", "ISBN13", "My Rating", "Number of Pages", "Year Published",
        "Date Read", "Date Added", "Exclusive Shelf", "Subtitle", "Language", "Date Started", "Current Page",
        "Source", "ESTER Record", "Open Library Key",
    ]

    /// Goodreads' words for its three shelves, and Loe's two more in the same style.
    static func name(of shelf: Shelf) -> String {
        switch shelf {
        case .reading: "currently-reading"
        case .wantToRead: "to-read"
        case .read: "read"
        case .setAside: "set-aside"
        case .didNotFinish: "did-not-finish"
        }
    }

    /// The whole file: a byte order mark, so a spreadsheet reads õ and ä as they
    /// are, the columns, then the books in the order they were added.
    static func csv(of books: [Book], timeZone: TimeZone = .current) -> String {
        let ordered = books.sorted { ($0.added, $0.title) < ($1.added, $1.title) }
        let lines = [columns.map(field)] + ordered.map { row(for: $0, timeZone: timeZone) }
        return "\u{FEFF}" + lines.map { $0.joined(separator: ",") + "\r\n" }.joined()
    }

    static func row(for book: Book, timeZone: TimeZone) -> [String] {
        let authors = (book.authors ?? "").split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        func day(_ date: Date?) -> String { date.map { Self.day($0, in: timeZone) } ?? "" }
        func number(_ value: Int?) -> String { value.map(String.init) ?? "" }
        return [
            text(book.title),
            text(authors.first ?? ""),
            text(authors.dropFirst().joined(separator: ", ")),
            digits(book.isbn),
            number(book.rating),
            number(book.pages),
            number(book.year),
            day(book.finished),
            day(book.added),
            name(of: book.shelf),
            text(book.subtitle ?? ""),
            text(book.language ?? ""),
            day(book.started),
            number(book.currentPage),
            book.source.rawValue,
            text(book.erbID),
            text(book.openLibraryKey ?? ""),
        ].map(field)
    }

    /// A day as Goodreads writes it, "2026/11/27", where the reader is.
    static func day(_ date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d/%02d/%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Text from a catalogue, Open Library or the reader. A spreadsheet runs a
    /// cell that starts like a formula, so one that does gets an apostrophe in
    /// front, which a spreadsheet takes to mean plain text.
    static func text(_ value: String) -> String {
        guard let first = value.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) else { return value }
        return "'" + value
    }

    /// An ISBN as Goodreads writes it, `="9780345451323"`, the one formula in the
    /// file: without it a spreadsheet shows thirteen digits as 9.78E+12. Anything
    /// that is not an ISBN's characters is left out.
    static func digits(_ isbn: String?) -> String {
        guard let isbn, !isbn.isEmpty, isbn.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "X") }) else { return "" }
        return "=\"\(isbn)\""
    }

    /// A field with a comma, a quote or a line break is wrapped in quotes, and its
    /// own quotes are doubled.
    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Writes the file into a folder of its own, so it keeps its name whatever
    /// else is there, and gives where it is.
    static func write(_ books: [Book], named name: String, in parent: URL = .temporaryDirectory) throws -> URL {
        let folder = parent.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try Data(csv(of: books).utf8).write(to: url)
        return url
    }

    /// The file's name, with the day it was made.
    static func fileName(on date: Date = .now, timeZone: TimeZone = .current) -> String {
        "Loe \(day(date, in: timeZone).replacingOccurrences(of: "/", with: "-")).csv"
    }
}

extension ShelvesExport.Book {
    init(_ book: ShelvedBook) {
        self.init(
            title: book.title, subtitle: book.subtitle, authors: book.authors, isbn: book.isbn, rating: book.rating,
            pages: book.pageCount, currentPage: book.currentPage, year: book.year, language: book.language,
            shelf: book.shelf, added: book.addedAt, started: book.startedAt, finished: book.finishedAt,
            source: book.source, erbID: book.erbID, openLibraryKey: book.openLibraryKey
        )
    }
}
