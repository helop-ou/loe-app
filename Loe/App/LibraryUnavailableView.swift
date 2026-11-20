import SwiftUI

/// What a reader sees when their shelves can't be opened, in place of a crash on
/// every launch. Nothing is deleted or replaced to get past it.
struct LibraryUnavailableView: View {
    let tryAgain: () -> Void

    var body: some View {
        EmptyState(
            title: "Your shelves can't be opened",
            systemImage: "books.vertical",
            description: "Nothing has been deleted. Your shelves are still on this phone, and in your iCloud when it is on. Try again, or write to us if it keeps happening."
        ) {
            Button("Try again", action: tryAgain)
                .buttonStyle(.borderedProminent)
                .tint(.loeAccent)
                .foregroundStyle(.loeOnAccent)
            // The empty state colours its text, which a tint alone does not override.
            Link("Write to us", destination: URL(string: "mailto:\(LoeProject.contact)")!)
                .foregroundStyle(.loeAccent)
        }
    }
}

#Preview {
    LibraryUnavailableView {}
}
