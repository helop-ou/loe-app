import Foundation

/// Where a reader can find a book outside Loe.
nonisolated enum BookLinks {
    /// The ESTER record. Its URL takes the record number without the check digit
    /// that the bibliography's 001 field ends with: b10500820 is record=b1050082.
    static func ester(_ erbID: String) -> URL? {
        guard erbID.count == 9, erbID.hasPrefix("b") else { return nil }
        return URL(string: "https://www.ester.ee/record=\(erbID.dropLast())")
    }

    static func rahvaRaamat(_ query: String) -> URL? {
        search("https://www.rahvaraamat.ee/otsing", query)
    }

    static func apollo(_ query: String) -> URL? {
        search("https://www.apollo.ee/catalogsearch/result/", query)
    }

    /// What to search a bookshop for: the title and its first author.
    static func query(for work: CatalogueWork) -> String {
        [work.title, work.editions[0].leadAuthor].compactMap { $0 }.joined(separator: " ")
    }

    private static func search(_ base: String, _ query: String) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}
