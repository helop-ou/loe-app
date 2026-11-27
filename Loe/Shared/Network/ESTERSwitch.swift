import SwiftUI

/// Whether Loe asks ESTER about books: which libraries have a copy, and the
/// covers and summaries of its cover service. The catalogue manifest can turn all
/// of it off, and nothing on. What a manifest last said is kept on the phone, so
/// it holds from launch. See docs/library.md, "Turning ESTER off".
nonisolated enum ESTERSwitch {
    static let key = "asksESTER"

    /// On until a manifest has said otherwise.
    static func isOn(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
    }
}

extension EnvironmentValues {
    /// False once the manifest has turned ESTER off. See `ESTERSwitch`.
    @Entry var asksESTER = true
}
