import Foundation

/// Whether two records are one book when the catalogue and Open Library write it
/// differently: the catalogue keeps a subtitle apart where Open Library puts it in
/// the title, either may drop a leading article, and authors come with or without a
/// middle initial. Search uses it to show a book once, and the shelves to keep it once.
nonisolated enum SameBook {
    /// Every way this book can be written: its title alone and with its subtitle,
    /// folded and without a leading article, with the lead author's surname.
    static func keys(title: String, subtitle: String? = nil, leadAuthor: String?) -> Set<String> {
        let surname = leadAuthor.flatMap { CatalogueQuery.folded($0).split(separator: " ").last.map(String.init) } ?? ""
        let titles = [title] + (subtitle.map { ["\(title): \($0)"] } ?? [])
        return Set(titles.map { plain($0) + "|" + surname })
    }

    private static func plain(_ title: String) -> String {
        var words = CatalogueQuery.folded(title).split(separator: " ")
        if words.count > 1, ["the", "a", "an"].contains(words[0]) { words.removeFirst() }
        return words.joined(separator: " ")
    }
}
