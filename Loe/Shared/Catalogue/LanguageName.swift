import Foundation

/// Names a catalogue language code (MARC's three letters, such as `fre`) in the
/// language Loe is showing, which a view reads from its environment: "French", or
/// "prantsuse" in Estonian.
nonisolated enum LanguageName {
    static func of(_ code: String?, in locale: Locale) -> String? {
        guard let code, !code.isEmpty else { return nil }
        return locale.localizedString(forLanguageCode: code)
    }
}
