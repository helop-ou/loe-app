import SwiftUI

/// Light and dark are both designed. Loe follows the phone unless the reader pins one.
enum LoeAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var name: LocalizedStringKey {
        switch self {
        case .system: "Same as the phone"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
