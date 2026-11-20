import Foundation

/// The language Loe shows. It follows the phone unless the reader picks one: iOS
/// has no Estonian of its own, so on a phone set to English Loe's Estonian would
/// never show.
nonisolated enum LoeLanguage: String, CaseIterable, Sendable {
    case system
    case estonian = "et"
    case english = "en"

    static let storageKey = "language"

    /// The language Loe shows: the one picked, or the one the phone gives Loe.
    func code(phoneGives preferred: [String] = Bundle.main.preferredLocalizations) -> String {
        self == .system ? preferred.first ?? "en" : rawValue
    }

    /// The language's name in that language. It is never translated, so a reader
    /// finds theirs whatever Loe is showing.
    func ownName(phoneGives preferred: [String] = Bundle.main.preferredLocalizations) -> String {
        code(phoneGives: preferred) == "et" ? "Eesti" : "English"
    }

    /// The phone's locale with Loe's language in it, so every word follows the
    /// language while dates and numbers keep the reader's region.
    func locale(onPhone phone: Locale = .current, phoneGives preferred: [String] = Bundle.main.preferredLocalizations) -> Locale {
        var components = Locale.Components(locale: phone)
        components.languageComponents.languageCode = Locale.LanguageCode(code(phoneGives: preferred))
        components.languageComponents.script = nil
        return Locale(components: components)
    }

    #if DEBUG
    /// A journey starts from the phone's language: `-forgetLanguage YES` drops the
    /// choice an earlier run left on the simulator.
    static func forgetIfAsked(in defaults: UserDefaults = .standard) {
        if defaults.bool(forKey: "forgetLanguage") { defaults.removeObject(forKey: storageKey) }
    }
    #endif
}

extension Locale {
    /// A string built in code, in this locale's language. `String(localized:)` on
    /// its own answers in the phone's language, whatever Loe is showing.
    nonisolated func localized(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = self
        return String(localized: resource)
    }
}
