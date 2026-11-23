#if DEBUG
import Foundation

/// Debug builds launched with `-networkStub YES` answer for the network
/// themselves, so a journey sees the same answers every time: Open Library, its
/// covers and ESTER answer from what their clients keep for it.
nonisolated enum NetworkStub {
    static var isOn: Bool {
        UserDefaults.standard.bool(forKey: "networkStub")
    }
}
#endif
