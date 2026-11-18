import Foundation

/// Names a catalogue language code (MARC's three letters, such as `fre`) in the
/// language Loe is showing: "French", or "prantsuse" in Estonian.
nonisolated enum LanguageName {
    static func of(_ code: String?, in locale: Locale = appLocale) -> String? {
        guard let code, !code.isEmpty else { return nil }
        return locale.localizedString(forLanguageCode: code)
    }

    static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }
}
