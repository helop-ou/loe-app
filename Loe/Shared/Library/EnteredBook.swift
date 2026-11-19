import Foundation

/// What a reader types in for a book the catalogue doesn't have, such as an
/// English book published abroad.
nonisolated struct EnteredBook: Equatable, Sendable {
    var title = ""
    /// Names as the reader typed them, several separated by commas.
    var authors = ""
    var pages: Int?
    var year: Int?
    /// A language code as the catalogue writes it, such as "eng". Books the
    /// catalogue lacks are mostly English ones from abroad.
    var language: String? = "eng"

    /// The languages offered, most likely first. Any other is left unset.
    static let languages = ["eng", "est", "rus", "fin", "ger", "fre", "spa"]

    /// Starts from what the reader searched for, unless it was an ISBN.
    init(searchedFor text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        title = CatalogueQuery.isbn13(trimmed) == nil ? trimmed : ""
    }

    init(title: String = "", authors: String = "", pages: Int? = nil, year: Int? = nil, language: String? = "eng") {
        self.title = title
        self.authors = authors
        self.pages = pages
        self.year = year
        self.language = language
    }

    var canSave: Bool { !cleanTitle.isEmpty }

    var cleanTitle: String { Self.tidy(title) }

    /// Authors the way the catalogue keeps them, separated by "; ".
    var cleanAuthors: String? {
        let names = authors.split(separator: ",").map { Self.tidy(String($0)) }.filter { !$0.isEmpty }
        return names.isEmpty ? nil : names.joined(separator: "; ")
    }

    var cleanPages: Int? {
        pages.flatMap { (1...20_000).contains($0) ? $0 : nil }
    }

    /// A year from the first printed books to next year. Anything else is a typo.
    var cleanYear: Int? {
        let next = Calendar(identifier: .gregorian).component(.year, from: .now) + 1
        return year.flatMap { (1450...next).contains($0) ? $0 : nil }
    }

    private static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
