import Foundation
import Testing

/// Every string Loe shows has a finished Estonian translation. A string left out
/// shows in English in the middle of an Estonian screen, and nothing else fails.
struct TranslationTests {
    private static let app = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Loe")

    @Test(arguments: ["Localizable", "InfoPlist"])
    func everyStringIsTranslatedIntoEstonian(catalogue: String) throws {
        let data = try Data(contentsOf: Self.app.appending(path: "\(catalogue).xcstrings"))
        let strings = try JSONDecoder().decode(StringCatalogue.self, from: data).strings
        #expect(!strings.isEmpty)
        let unfinished = strings.filter { !$0.value.isFinished(in: "et") }.keys.sorted()
        #expect(unfinished.isEmpty, "No finished Estonian translation for: \(unfinished)")
    }

    @Test func aStringIsFinishedOnlyWhenEveryFormIsTranslated() throws {
        let json = #"""
            {"strings": {
              "done": {"localizations": {"et": {"stringUnit": {"state": "translated", "value": "valmis"}}}},
              "missing": {"localizations": {"de": {"stringUnit": {"state": "translated", "value": "fertig"}}}},
              "bare": {},
              "to review": {"localizations": {"et": {"stringUnit": {"state": "needs_review", "value": "vaata üle"}}}},
              "new": {"localizations": {"et": {"stringUnit": {"state": "new", "value": ""}}}},
              "empty": {"localizations": {"et": {"stringUnit": {"state": "translated", "value": ""}}}},
              "%lld pages": {"localizations": {"et": {"variations": {"plural": {
                "one": {"stringUnit": {"state": "translated", "value": "%lld lk"}},
                "other": {"stringUnit": {"state": "translated", "value": "%lld lk"}}}}}}},
              "%lld books": {"localizations": {"et": {"variations": {"plural": {
                "one": {"stringUnit": {"state": "translated", "value": "%lld raamat"}},
                "other": {"stringUnit": {"state": "needs_review", "value": "%lld raamatut"}}}}}}},
              "no forms": {"localizations": {"et": {"variations": {"plural": {}}}}},
              "Loe": {"shouldTranslate": false}
            }}
            """#
        let strings = try JSONDecoder().decode(StringCatalogue.self, from: Data(json.utf8)).strings
        let finished = strings.filter { $0.value.isFinished(in: "et") }.keys.sorted()
        #expect(finished == ["%lld pages", "Loe", "done"])
    }
}

/// What the test reads of a string catalogue.
private struct StringCatalogue: Decodable {
    let strings: [String: Entry]

    struct Entry: Decodable {
        var shouldTranslate: Bool?
        var localizations: [String: Localization]?

        func isFinished(in language: String) -> Bool {
            shouldTranslate == false || localizations?[language]?.isFinished == true
        }
    }

    struct Localization: Decodable {
        var stringUnit: Unit?
        var variations: Variations?

        var isFinished: Bool {
            if let stringUnit { return stringUnit.isFinished }
            let forms = (variations?.plural ?? [:]).values.map(\.stringUnit)
            return !forms.isEmpty && forms.allSatisfy { $0?.isFinished == true }
        }
    }

    struct Variations: Decodable {
        var plural: [String: Form]?
    }

    struct Form: Decodable {
        var stringUnit: Unit?
    }

    struct Unit: Decodable {
        var state: String?
        var value: String?

        var isFinished: Bool { state == "translated" && value?.isEmpty == false }
    }
}
