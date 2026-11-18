import SwiftUI

/// A screen with nothing on it yet, on Loe's own background and in its text colours.
struct EmptyState<Actions: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey
    @ViewBuilder var actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
                .foregroundStyle(.loeSecondary)
        } actions: {
            actions
        }
        .foregroundStyle(.loeInk, .loeSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.loeBackground)
    }
}

extension EmptyState where Actions == EmptyView {
    init(title: LocalizedStringKey, systemImage: String, description: LocalizedStringKey) {
        self.init(title: title, systemImage: systemImage, description: description) { EmptyView() }
    }
}

#Preview {
    EmptyState(title: "Your shelves are empty", systemImage: "books.vertical", description: "Find a book in Search and add it to a shelf.")
}
