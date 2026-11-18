import Foundation

/// Turns what a reader types into a catalogue lookup.
nonisolated enum CatalogueQuery {
    /// An FTS5 match expression: every word must appear, and the last may still be
    /// being typed. Nil when there is nothing to search for.
    static func match(for text: String) -> String? {
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        let quoted = words.map { "\"\($0)\"" }
        return quoted.dropLast().joined(separator: " ") + (words.count > 1 ? " " : "") + quoted.last! + "*"
    }

    /// The ISBN-13 a reader typed or scanned, in any punctuation, or nil.
    static func isbn13(_ text: String) -> String? {
        let characters = text.uppercased().filter { $0.isNumber || $0 == "X" }
        guard characters.count == 10 || characters.count == 13, text.allSatisfy({ $0.isNumber || "Xx- ".contains($0) }) else {
            return nil
        }
        let digits = characters.map { $0 == "X" ? 10 : Int(String($0))! }
        let core: [Int]
        if digits.count == 10 {
            let sum = digits.enumerated().reduce(0) { $0 + (10 - $1.offset) * $1.element }
            guard sum % 11 == 0, !digits.dropLast().contains(10) else { return nil }
            core = [9, 7, 8] + digits.prefix(9)
        } else {
            guard !digits.contains(10) else { return nil }
            core = Array(digits.prefix(12))
        }
        let weighted = core.enumerated().reduce(0) { $0 + ($1.offset.isMultiple(of: 2) ? 1 : 3) * $1.element }
        let full = core + [(10 - weighted % 10) % 10]
        guard digits.count == 10 || full == digits else { return nil }
        return full.map(String.init).joined()
    }

    /// Lowercased, without diacritics or punctuation, for comparing titles.
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
