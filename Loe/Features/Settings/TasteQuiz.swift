import SwiftData
import SwiftUI

/// Asked once, on first launch: which kinds of book the reader likes. Skipping keeps
/// nothing, and Settings can change the answers later.
struct TasteQuiz: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<Genre> = []

    /// Set once the quiz has been shown, so it is not asked again.
    static let seenKey = "tasteQuizSeen"

    var body: some View {
        NavigationStack {
            ScrollView {
                TasteQuizContent(selection: $selection)
            }
            .background(.loeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? Taste.set(selection, in: context)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
}

/// The quiz without its buttons, so it can be looked at on its own.
struct TasteQuizContent: View {
    @Binding var selection: Set<Genre>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What do you like to read?")
                .loeHeading(.largeTitle)
                .foregroundStyle(.loeInk)
            Text("Pick a few and Loe will suggest books from them. It's worked out on your phone, and you can change it in Settings.")
                .foregroundStyle(.loeSecondary)
                .padding(.bottom, 8)
            GenrePicker(selection: $selection)
        }
        .padding(20)
    }
}

#Preview {
    TasteQuiz()
        .modelContainer(for: [ShelvedBook.self, Taste.self], inMemory: true)
}
