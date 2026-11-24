import Foundation

/// What a book is about, from its work record on Open Library, as plain text.
/// Open Library writes a description in Markdown, as a string or inside an
/// object, and adds its own notes under a rule: what the work contains and what
/// to see also. See docs/catalogue.md, "Books from abroad".
nonisolated enum OpenLibraryDescription {
    /// The description in a work record, or nil when it has none worth showing.
    static func text(inWork data: Data) -> String? {
        guard let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let written = record["description"] as? String ?? (record["description"] as? [String: Any])?["value"] as? String
        return written.flatMap(plain)
    }

    /// The text without Open Library's notes, Markdown or links, in paragraphs.
    static func plain(_ markdown: String) -> String? {
        var lines: [String] = []
        for line in markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // A rule, and everything under it, is Open Library's own.
            if trimmed.count >= 3, trimmed.allSatisfy({ $0 == "-" }) { break }
            // A link's address, written apart from the link.
            if trimmed.wholeMatch(of: /\[[^\]]+\]:\s*\S+.*/) != nil { continue }
            lines.append(trimmed)
        }
        let text = lines.joined(separator: "\n")
            .replacing(/\(?\[[Ss]ource\]\[\d+\]\)?/, with: "")
            .replacing(/\[([^\]]+)\]\([^)]*\)/) { String($0.output.1) }
            .replacing(/\[([^\]]+)\]\[\d*\]/) { String($0.output.1) }
            .replacing(/\*\*([^*\n]+)\*\*/) { String($0.output.1) }
            .replacing(/\*([^*\n]+)\*/) { String($0.output.1) }
            .replacing(/\\([\[\]*_])/) { String($0.output.1) }
            .replacing(/[ \t]+\n/, with: "\n")
            .replacing(/\n{3,}/, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
