import Foundation

/// One author written two ways. The bibliography and Open Library mostly agree on
/// a name, and where they don't it is a middle name or an initial that one has and
/// the other leaves out: Gerald Durrell and Gerald Malcolm Durrell. The
/// bibliography also uses a middle name to tell two people apart, so a name only
/// fits another when nothing in it says otherwise. See docs/catalogue.md, "In the
/// app".
nonisolated enum AuthorName {
    /// A name's words, folded: the first name, what stands between, and the surname.
    struct Parts: Equatable {
        let first: String
        let middle: [String]
        let surname: String
    }

    /// Nil for a name of one word, which has nothing to compare by.
    static func parts(_ name: String) -> Parts? {
        let words = CatalogueQuery.folded(name).split(separator: " ").map(String.init)
        guard words.count > 1 else { return nil }
        return Parts(first: words[0], middle: Array(words.dropFirst().dropLast()), surname: words[words.count - 1])
    }

    /// Whether the two can be one person: the same first name, spelled out, the
    /// same surname, and nothing between them that contradicts. A middle name one
    /// leaves out fits any, and an initial fits a name that starts with it. An
    /// initial in place of the first name fits nobody: H. G. Wells is not
    /// Henrietta Wells.
    static func fits(_ one: String, _ other: String) -> Bool {
        guard let a = parts(one), let b = parts(other) else { return false }
        guard a.first == b.first, a.first.count > 1, a.surname == b.surname else { return false }
        return zip(a.middle, b.middle).allSatisfy { mine, theirs in
            mine == theirs || (mine.count == 1 && theirs.hasPrefix(mine)) || (theirs.count == 1 && mine.hasPrefix(theirs))
        }
    }

    /// The one spelling among these that can be this author, or nil when none fits
    /// or more than one does: two that fit may be two people.
    static func onlySpelling(of name: String, among spellings: some Sequence<String>) -> String? {
        var found: String?
        for spelling in spellings where fits(spelling, name) {
            guard let known = found else {
                found = spelling
                continue
            }
            if CatalogueQuery.folded(known) != CatalogueQuery.folded(spelling) { return nil }
        }
        return found
    }
}
