import SwiftUI

/// A screen with nothing on it yet, on Loe's own background and in its text colours.
struct EmptyState: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
                .foregroundStyle(.loeSecondary)
        }
        .foregroundStyle(.loeInk, .loeSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.loeBackground)
    }
}

#Preview {
    EmptyState(title: "Your shelves are empty", systemImage: "books.vertical", description: "Find a book in Search and add it to a shelf.")
}
