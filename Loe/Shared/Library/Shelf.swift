import SwiftUI

/// The five shelves. Told apart by shape and two colours, not five: Reading is a
/// filled accent dot, Want to read an accent ring, Read a filled ink dot, Set aside
/// a filled grey dot, Didn't finish a grey ring. Not finishing a book gets no red.
nonisolated enum Shelf: String, CaseIterable, Codable, Sendable {
    case reading
    case wantToRead
    case read
    case setAside
    case didNotFinish

    var name: LocalizedStringResource {
        switch self {
        case .reading: "Reading"
        case .wantToRead: "Want to read"
        case .read: "Read"
        case .setAside: "Set aside"
        case .didNotFinish: "Didn't finish"
        }
    }
}
