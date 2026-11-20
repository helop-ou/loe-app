import Foundation
import Testing
@testable import Loe

/// The language Loe shows: the phone's unless the reader picks one, and then every
/// word follows the pick while dates and numbers stay the reader's region's.
@MainActor
struct LoeLanguageTests {
    /// An English phone in Estonia, as the simulators are set.
    private let englishPhone = Locale(identifier: "en_US@rg=eezzzz")
    private let afternoon = Date(timeIntervalSince1970: 15 * 3600)
    private let day = Date.FormatStyle(date: .long, time: .omitted, timeZone: .gmt)
    private let time = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: .gmt)

    @Test func theStoredNamesStayAsTheyAre() {
        #expect(LoeLanguage.storageKey == "language")
        #expect(LoeLanguage.allCases.map(\.rawValue) == ["system", "et", "en"])
        // A name a later version might store reads as nothing, so the phone's language shows.
        #expect(LoeLanguage(rawValue: "fi") == nil)
    }

    @Test func itFollowsThePhoneUntilTheReaderPicks() {
        #expect(LoeLanguage.system.code(phoneGives: ["et"]) == "et")
        #expect(LoeLanguage.system.code(phoneGives: ["en"]) == "en")
        #expect(LoeLanguage.system.code(phoneGives: []) == "en")
        #expect(LoeLanguage.estonian.code(phoneGives: ["en"]) == "et")
        #expect(LoeLanguage.english.code(phoneGives: ["et"]) == "en")
    }

    @Test func aLanguageIsNamedInItself() {
        #expect(LoeLanguage.estonian.ownName(phoneGives: ["en"]) == "Eesti")
        #expect(LoeLanguage.english.ownName(phoneGives: ["et"]) == "English")
        #expect(LoeLanguage.system.ownName(phoneGives: ["et"]) == "Eesti")
        #expect(LoeLanguage.system.ownName(phoneGives: ["en"]) == "English")
    }

    @Test func thePickChangesTheWordsAndKeepsTheRegion() {
        let estonian = LoeLanguage.estonian.locale(onPhone: englishPhone, phoneGives: ["en"])
        #expect(estonian.language.languageCode?.identifier == "et")
        #expect(estonian.region?.identifier == "EE")
        #expect(afternoon.formatted(day.locale(estonian)).contains("jaanuar"))
        #expect(afternoon.formatted(time.locale(estonian)) == "15:00")

        // English words, with the day first and the clock an Estonian phone keeps.
        let english = LoeLanguage.english.locale(onPhone: Locale(identifier: "et_EE"), phoneGives: ["et"])
        #expect(english.language.languageCode?.identifier == "en")
        #expect(english.region?.identifier == "EE")
        #expect(afternoon.formatted(day.locale(english)).contains("January"))
        #expect(afternoon.formatted(day.locale(english)).hasPrefix("1"))
        #expect(afternoon.formatted(time.locale(english)) == "15:00")

        // An American phone keeps its own clock in Estonian.
        let american = LoeLanguage.estonian.locale(onPhone: Locale(identifier: "en_US"), phoneGives: ["en"])
        #expect(afternoon.formatted(day.locale(american)).contains("jaanuar"))
        #expect(afternoon.formatted(time.locale(american)).contains("PM"))
    }

    @Test func aPhoneInALanguageLoeLacksShowsEnglishWithItsOwnRegion() {
        let finnishPhone = LoeLanguage.system.locale(onPhone: Locale(identifier: "fi_FI"), phoneGives: ["en"])
        #expect(finnishPhone.language.languageCode?.identifier == "en")
        #expect(finnishPhone.region?.identifier == "FI")
        #expect(LanguageName.of("fre", in: finnishPhone) == "French")
    }

    @Test func thePhonesOwnLanguageLeavesItsLocaleAlone() {
        #expect(LoeLanguage.system.locale(onPhone: englishPhone, phoneGives: ["en"]).identifier == englishPhone.identifier)
    }

    @Test func aStringBuiltInCodeFollowsTheLanguage() {
        let estonian = LoeLanguage.estonian.locale(onPhone: englishPhone, phoneGives: ["en"])
        let english = LoeLanguage.english.locale(onPhone: Locale(identifier: "et_EE"), phoneGives: ["et"])
        #expect(estonian.localized("Not started") == "Pole veel alustanud")
        #expect(english.localized("Not started") == "Not started")
        #expect(estonian.localized("\(1) editions") == "1 väljaanne")
        #expect(estonian.localized("\(3) editions") == "3 väljaannet")
        #expect(english.localized("\(3) editions") == "3 editions")
        #expect(Locale(identifier: "fi_FI").localized("Not started") == "Not started")
    }

    @Test func theReadingProgressIsInTheLanguageShowing() {
        let edition = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull", authors: "Jaan Kross", pages: 352)
        let book = ShelvedBook(edition: edition, workKey: CatalogueWork.key(for: edition), shelf: .reading)
        let estonian = Locale(identifier: "et_EE")
        #expect(ReadingProgress.pageText(book, in: estonian) == "Pole veel alustanud")
        book.currentPage = 12
        book.pageCount = 300
        #expect(ReadingProgress.pageText(book, in: estonian) == "lk 12 / 300")
        #expect(ReadingProgress.pageText(book, in: Locale(identifier: "en_EE")) == "p. 12 of 300")
    }

    #if DEBUG
    @Test func aJourneyCanStartFromThePhonesLanguage() throws {
        let name = "LoeLanguageTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(LoeLanguage.estonian.rawValue, forKey: LoeLanguage.storageKey)
        LoeLanguage.forgetIfAsked(in: defaults)
        #expect(defaults.string(forKey: LoeLanguage.storageKey) == "et")
        defaults.set(true, forKey: "forgetLanguage")
        LoeLanguage.forgetIfAsked(in: defaults)
        #expect(defaults.string(forKey: LoeLanguage.storageKey) == nil)
    }
    #endif

    /// `String(localized:)` answers in the phone's language, and a plain navigation
    /// title keeps the language its screen first appeared in.
    @Test func everyFileAsksInTheLanguageShowing() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let enumerator = try #require(FileManager.default.enumerator(at: root.appending(path: "Loe"), includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count > 50)
        let allowed = ["String(localized": "/App/LoeLanguage.swift", ".navigationTitle(": "/Shared/UI/NavigationTitles.swift"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (forbidden, home) in allowed where !file.path.hasSuffix(home) {
                #expect(!text.contains(forbidden), "\(file.path) uses \(forbidden), which does not follow the language Loe shows")
            }
        }
    }
}
