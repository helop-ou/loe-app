import SwiftUI

/// A shelf's mark: a dot or a ring, in the accent, ink or the quiet grey.
struct ShelfMark: View {
    let shelf: Shelf
    var size: CGFloat = 13

    var body: some View {
        Group {
            switch shelf {
            case .reading: Circle().fill(.loeAccent)
            case .wantToRead: Circle().strokeBorder(.loeAccent, lineWidth: size * 0.19)
            case .read: Circle().fill(.loeInk)
            case .setAside: Circle().fill(.loeQuiet)
            case .didNotFinish: Circle().strokeBorder(.loeQuiet, lineWidth: size * 0.19)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading) {
        ForEach(Shelf.allCases, id: \.self) { shelf in
            Label { Text(shelf.name) } icon: { ShelfMark(shelf: shelf) }
        }
    }
    .padding()
}
