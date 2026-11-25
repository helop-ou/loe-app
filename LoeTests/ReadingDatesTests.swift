import Foundation
import Testing
@testable import Loe

/// When a book was started and finished, as the reader sets them on its page.
struct ReadingDatesTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Tallinn")!
        return calendar
    }()

    /// A day of November 2026, in Tallinn.
    private static func day(_ day: Int, at hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private let today = ReadingDatesTests.day(25, at: 18)

    private func settled(_ dates: ReadingDates, replacing old: ReadingDates = ReadingDates()) -> ReadingDates {
        dates.settled(replacing: old, now: today, calendar: Self.calendar)
    }

    /// At noon the day is the same day a good way east and west of where it was set.
    @Test func aDayTheReaderPickedIsKeptAtNoon() {
        let kept = settled(ReadingDates(started: Self.day(3, at: 0), finished: Self.day(24, at: 23)))
        #expect(kept == ReadingDates(started: Self.day(3, at: 12), finished: Self.day(24, at: 12)))
    }

    /// The picker hands back every date, changed or not, and saving must not
    /// rewrite the ones the reader left alone.
    @Test func aDayLeftAloneKeepsItsMoment() {
        let old = ReadingDates(started: Self.day(3, at: 9), finished: Self.day(20, at: 21))
        let kept = settled(ReadingDates(started: Self.day(3, at: 15), finished: Self.day(21, at: 0)), replacing: old)
        #expect(kept.started == Self.day(3, at: 9))
        #expect(kept.finished == Self.day(21, at: 12))
        #expect(settled(old, replacing: old) == old)
    }

    @Test func noDayIsAfterToday() {
        let kept = settled(ReadingDates(started: Self.day(26), finished: Self.day(30)))
        #expect(kept == ReadingDates(started: Self.day(25, at: 12), finished: Self.day(25, at: 12)))
        // Today itself is fine, later in the day than now too.
        #expect(settled(ReadingDates(finished: Self.day(25, at: 23))).finished == Self.day(25, at: 12))
    }

    @Test func aFinishIsNeverBeforeTheStart() {
        let kept = settled(ReadingDates(started: Self.day(10), finished: Self.day(5)))
        #expect(kept == ReadingDates(started: Self.day(10, at: 12), finished: Self.day(10, at: 12)))
        // Started and finished on one day is a short book, not a mistake.
        let oneDay = ReadingDates(started: Self.day(10, at: 20), finished: Self.day(10, at: 8))
        #expect(settled(oneDay, replacing: oneDay) == oneDay)
    }

    @Test func eitherDateCanBeCleared() {
        let old = ReadingDates(started: Self.day(3), finished: Self.day(20))
        #expect(settled(ReadingDates(finished: Self.day(20)), replacing: old) == ReadingDates(finished: Self.day(20)))
        #expect(settled(ReadingDates(started: Self.day(3)), replacing: old) == ReadingDates(started: Self.day(3)))
        #expect(settled(ReadingDates(), replacing: old) == ReadingDates())
    }

    /// A day is written as the reader's region writes it: English in Estonia keeps
    /// the full stop after the day.
    @Test func aBooksPageSaysWhenItWasStartedAndFinished() {
        let dates = ReadingDates(started: Self.day(3), finished: Self.day(24))
        let tallinn = Self.calendar.timeZone
        #expect(dates.lines(on: .read, in: Locale(identifier: "en_EE"), timeZone: tallinn) == ["Started 3. November 2026", "Finished 24. November 2026"])
        #expect(dates.lines(on: .read, in: Locale(identifier: "et_EE"), timeZone: tallinn) == ["Alustatud 3. november 2026", "Lõpetatud 24. november 2026"])
        #expect(ReadingDates(finished: Self.day(24)).lines(on: .read, in: Locale(identifier: "en_EE"), timeZone: tallinn) == ["Finished 24. November 2026"])
        #expect(ReadingDates().lines(on: .read, in: Locale(identifier: "en_EE"), timeZone: tallinn).isEmpty)
    }

    /// A book moved off Read still has its finish, from the reading before.
    @Test func theFinishShowsOnlyForABookThatIsRead() {
        let dates = ReadingDates(started: Self.day(3), finished: Self.day(24))
        let english = Locale(identifier: "en_EE")
        for shelf in Shelf.allCases where shelf != .read {
            #expect(dates.lines(on: shelf, in: english, timeZone: Self.calendar.timeZone) == ["Started 3. November 2026"])
            #expect(!ReadingDates.showsFinish(on: shelf))
        }
        #expect(ReadingDates.showsFinish(on: .read))
    }

    /// A book the reader only wants to read has nothing to date yet.
    @Test func theDatesAreOfferedOnceThereIsSomethingToDate() {
        #expect(!ReadingDates().isOffered(on: .wantToRead))
        #expect(ReadingDates(started: Self.day(3)).isOffered(on: .wantToRead))
        for shelf in Shelf.allCases where shelf != .wantToRead {
            #expect(ReadingDates().isOffered(on: shelf))
        }
    }
}
