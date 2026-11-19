import Foundation

/// One copy of an edition in an ESTER library: where it is, and whether a reader
/// can take it home. See docs/library.md, "Availability".
nonisolated struct LibraryCopy: Hashable, Sendable {
    enum State: Hashable, Sendable {
        case onShelf
        /// On loan until this day.
        case onLoan(DateComponents)
        /// In storage, so it can be ordered.
        case inStorage
        /// Between branches.
        case inTransit
        /// Reference, reading room or archive: only to read in the library.
        case readThere
    }

    /// The holdings row's location, such as "TlnRK Kännukuke lastekirjandus".
    let location: String
    let state: State
}

/// What a library has of a book, across all its editions, for one row of "Where to
/// get it". The first that applies wins, so a copy on the shelf beats one in storage.
nonisolated enum LibraryAvailability: Hashable, Sendable {
    case onShelf
    /// Another edition is on the shelf, though the one on screen is not.
    case otherEditionOnShelf(year: Int?)
    case inStorage
    /// On loan, back on the earliest due date to come, or nil when every copy is overdue.
    case onLoan(DateComponents?)
    case inTransit
    case readThere
    case notHere

    /// `copies` holds each edition's copies, by the edition's ERB number. `onScreen`
    /// is the edition the book's page shows.
    static func of(
        _ place: Place,
        copies: [String: [LibraryCopy]],
        editions: [CatalogueEdition],
        onScreen: String,
        today: Date = .now
    ) -> LibraryAvailability {
        let here = copies.mapValues { $0.filter { Place.library(forLocation: $0.location) == place } }
        let all = here.values.joined()
        if here[onScreen]?.contains(where: { $0.state == .onShelf }) == true {
            return .onShelf
        }
        // Newest first, so the edition named is the most recent one on the shelf.
        if let other = editions.first(where: { here[$0.erbID]?.contains { $0.state == .onShelf } == true }) {
            return .otherEditionOnShelf(year: other.year)
        }
        if all.contains(where: { $0.state == .inStorage }) { return .inStorage }
        let due = all.compactMap { copy -> DateComponents? in
            if case .onLoan(let date) = copy.state { date } else { nil }
        }
        if !due.isEmpty {
            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.startOfDay(for: today)
            let coming = due.compactMap { day in calendar.date(from: day).map { (day, $0) } }.filter { $0.1 >= start }
            return .onLoan(coming.min { $0.1 < $1.1 }?.0)
        }
        if all.contains(where: { $0.state == .inTransit }) { return .inTransit }
        if all.contains(where: { $0.state == .readThere }) { return .readThere }
        return .notHere
    }
}

/// Reads an ESTER holdings page: the web catalogue's list of every copy of one record.
nonisolated enum ESTERHoldings {
    /// The page listing every copy of an edition, with Estonian labels. Nil for an
    /// ERB number that is not a record.
    static func url(erbID: String) -> URL? {
        // The check digit can be x, as in b1210534x.
        guard erbID.count == 9, erbID.hasPrefix("b"), erbID.dropFirst().dropLast().allSatisfy(\.isNumber),
              let check = erbID.last, check.isNumber || check == "x"
        else { return nil }
        // The record is the ERB number without its check digit.
        let record = erbID.dropLast()
        let number = record.dropFirst()
        return URL(string: "https://www.ester.ee/search*est?/.\(record)/.\(record)/1,1,1,B/holdings~\(number)&FF=&1,0,")
    }

    /// Copies whose due date is this long past are taken to be lost.
    static let lostAfterDays = 60

    /// The copies on a holdings page. Rows that say nothing a reader can use, such
    /// as a copy packed away during renovation or one billed as lost, are left out.
    static func copies(in page: String, today: Date = .now) -> [LibraryCopy] {
        rows(in: page).compactMap { copy(location: $0.location, status: $0.status, note: $0.note, today: today) }
    }

    static func copy(location: String, status: String, note: String, today: Date) -> LibraryCopy? {
        let status = status.uppercased()
        let place = location.lowercased()
        let note = note.uppercased()
        let state: LibraryCopy.State
        if status.hasPrefix("TÄHTAEG") {
            guard let due = dueDate(status), !isLong(past: due, today: today) else { return nil }
            state = .onLoan(due)
        } else if status == "TEEL" {
            state = .inTransit
        } else if status.contains("VARUKOGUS") {
            state = .inStorage
        } else if status == "KOHALKASUTUS" || status == "ARHIIVEKSEMPLAR" || note.contains("KOHALKASUTUS")
            || note.contains("EI LAENUTATA") || ["teatmekogu", "lugemissaal", "kohalkasutus", "arhiiv", "telli saali"].contains(where: place.contains) {
            guard status == "KOHAL" || status == "KOHALKASUTUS" || status == "ARHIIVEKSEMPLAR" else { return nil }
            state = .readThere
        } else if status == "KOHAL" || status == "TEAVIK TAGASTAMISEL" {
            // A copy in a library's store is fetched on request, but open stacks
            // ("avahoidla") are shelves readers walk into.
            state = place.contains("hoidla") && !place.contains("avahoidla") ? .inStorage : .onShelf
        } else {
            return nil
        }
        return LibraryCopy(location: location, state: state)
    }

    /// "TÄHTAEG 01.12.26" is due on 1 December 2026.
    static func dueDate(_ status: String) -> DateComponents? {
        guard let match = status.firstMatch(of: /(\d{2})\.(\d{2})\.(\d{2})/),
              let day = Int(match.1), let month = Int(match.2), let year = Int(match.3)
        else { return nil }
        return DateComponents(year: 2000 + year, month: month, day: day)
    }

    private static func isLong(past due: DateComponents, today: Date) -> Bool {
        guard let date = Calendar(identifier: .gregorian).date(from: due) else { return true }
        return today.timeIntervalSince(date) > Double(lostAfterDays) * 86_400
    }

    /// The rows of the holdings table. Each cell starts with a comment naming its
    /// field: 1 is the location, % the status and ! a note.
    static func rows(in page: String) -> [(location: String, status: String, note: String)] {
        page.matches(of: /(?s)<tr[^>]*class="bibItemsEntry"[^>]*>(.*?)<\/tr>/).compactMap { row in
            let html = String(row.1)
            guard let location = field("1", in: html), !location.isEmpty else { return nil }
            return (location, field("%", in: html) ?? "", field("!", in: html) ?? "")
        }
    }

    private static func field(_ code: String, in row: String) -> String? {
        let marker = "<!-- field \(code) -->"
        guard let start = row.range(of: marker) else { return nil }
        let rest = row[start.upperBound...]
        let cell = rest[..<(rest.range(of: "</td>")?.lowerBound ?? rest.endIndex)]
        return text(String(cell))
    }

    /// Markup and comments removed, entities decoded, spaces collapsed.
    private static func text(_ html: String) -> String {
        var text = html
            .replacing(/(?s)<!--.*?-->/, with: " ")
            .replacing(/<[^>]+>/, with: " ")
        for (entity, character) in ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
