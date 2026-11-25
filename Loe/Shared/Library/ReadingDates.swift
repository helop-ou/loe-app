import Foundation

/// When the reader started a book and when they finished it. Moving a book
/// records them, and the reader can change or clear either on the book's page.
/// See docs/library.md, "Rules".
nonisolated struct ReadingDates: Equatable, Sendable {
    var started: Date?
    var finished: Date?

    /// The dates as they are kept, from what the reader picked: no day after
    /// today, and no finish before the start. A day the reader left alone keeps
    /// its moment. One they changed is kept at noon, so that it stays the same
    /// day when the phone moves to another time zone.
    func settled(replacing old: ReadingDates, now: Date, calendar: Calendar = .current) -> ReadingDates {
        func day(_ picked: Date?, _ kept: Date?) -> Date? {
            guard let picked else { return nil }
            let day = min(picked, now)
            if let kept, calendar.isDate(day, inSameDayAs: kept) { return kept }
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        }
        let started = day(started, old.started)
        var finished = day(finished, old.finished)
        if let started, let finish = finished, calendar.compare(finish, to: started, toGranularity: .day) == .orderedAscending {
            finished = started
        }
        return ReadingDates(started: started, finished: finished)
    }

    /// Whether a finish belongs to the book where it is now. On any shelf but
    /// Read, a finish it still has is from a reading that came before.
    static func showsFinish(on shelf: Shelf) -> Bool {
        shelf == .read
    }

    /// Whether a book's page offers the dates: once a book was started, and on
    /// every shelf but Want to read, where there is nothing to date yet.
    func isOffered(on shelf: Shelf) -> Bool {
        started != nil || shelf != .wantToRead
    }

    /// What a book's page says, a line for each date it shows.
    func lines(on shelf: Shelf, in locale: Locale, timeZone: TimeZone = .current) -> [String] {
        let day = Date.FormatStyle(date: .long, time: .omitted, locale: locale, timeZone: timeZone)
        var lines: [String] = []
        if let started {
            lines.append(locale.localized("Started \(started.formatted(day))"))
        }
        if Self.showsFinish(on: shelf), let finished {
            lines.append(locale.localized("Finished \(finished.formatted(day))"))
        }
        return lines
    }
}
