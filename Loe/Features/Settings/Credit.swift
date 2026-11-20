import SwiftUI

/// Someone whose work Loe is built on, what it gives the reader, and its licence
/// when Loe ships a copy of their work.
struct Credit: Identifiable {
    struct Licence: Hashable {
        let name: String
        /// A text file in Resources/Licenses.
        let file: String

        var text: String? {
            Bundle.main.url(forResource: file, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }
    }

    let id: String
    let name: LocalizedStringKey
    let role: LocalizedStringKey
    let about: LocalizedStringKey
    let link: URL
    var licence: Licence?

    static let all: [Credit] = [
        Credit(
            id: "national-library",
            name: "National Library of Estonia",
            role: "The catalogue",
            about: "Loe's catalogue is built from the Estonian National Bibliography, the National Library's record of the books published in Estonia. It is open data under CC0 1.0.",
            link: URL(string: "https://www.rara.ee")!,
            licence: Licence(name: "CC0 1.0 Universal", file: "CC0-1.0")
        ),
        Credit(
            id: "ester",
            name: "ESTER and ELNET",
            role: "Whether a library has a book",
            about: "Availability comes from ESTER, the catalogue Estonian libraries share, run by the ELNET Consortium.",
            link: URL(string: "https://www.ester.ee")!
        ),
        Credit(
            id: "open-library",
            name: "Open Library",
            role: "Books from abroad, and covers",
            about: "Books published abroad and the covers of books come from Open Library, an open catalogue run by the Internet Archive.",
            link: URL(string: "https://openlibrary.org")!
        ),
        Credit(
            id: "newsreader",
            name: "Newsreader",
            role: "The typeface for headings",
            about: "Headings are set in Newsreader by Production Type. Copyright 2020 The Newsreader Project Authors.",
            link: URL(string: "https://github.com/productiontype/Newsreader")!,
            licence: Licence(name: "SIL Open Font License 1.1", file: "Newsreader-OFL")
        ),
    ]

    /// A licence file's paragraphs, joined up from its fixed-width lines so they
    /// wrap to the screen. Headings and the items of a list keep their own line.
    nonisolated static func paragraphs(of text: String) -> [String] {
        var paragraphs: [String] = []
        var current: [String] = []
        func close() {
            if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
            current = []
        }
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.allSatisfy({ $0 == "-" }) {
                close()
            } else if current.isEmpty, isHeading(line) {
                close()
                paragraphs.append(line)
            } else {
                if startsListItem(line) { close() }
                current.append(line)
            }
        }
        close()
        return paragraphs
    }

    /// A short line in capitals that starts a paragraph, such as "PREAMBLE". A
    /// disclaimer in capitals runs longer.
    nonisolated private static func isHeading(_ line: String) -> Bool {
        line.count <= 40 && line.contains(where: \.isLetter) && !line.contains(where: \.isLowercase)
    }

    nonisolated private static func startsListItem(_ line: String) -> Bool {
        line.wholeMatch(of: #/(\d+|[a-z]|[ivx]+)\.\s.*/#) != nil
    }
}
