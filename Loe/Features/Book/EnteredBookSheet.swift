import SwiftUI

/// The form for a book the catalogue doesn't have: adding one, or changing what
/// the reader entered for it.
struct EnteredBookSheet: View {
    let heading: LocalizedStringResource
    let onSave: (EnteredBook) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var book: EnteredBook
    @FocusState private var titleFocused: Bool
    private let languages: [String]

    init(_ heading: LocalizedStringResource, book: EnteredBook, onSave: @escaping (EnteredBook) -> Void) {
        self.heading = heading
        self.onSave = onSave
        _book = State(initialValue: book)
        // A language this list doesn't offer stays selectable, so editing keeps it.
        let offered = EnteredBook.languages
        languages = book.language.map { offered.contains($0) ? offered : offered + [$0] } ?? offered
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $book.title)
                        .focused($titleFocused)
                    TextField("Author", text: $book.authors)
                        .textContentType(.name)
                } footer: {
                    Text("Separate several authors with commas.")
                }
                Section {
                    number("Pages", $book.pages, format: .number)
                    number("Year", $book.year, format: .number.grouping(.never))
                    Picker("Language", selection: $book.language) {
                        ForEach(languages, id: \.self) { code in
                            Text(LanguageName.of(code, in: locale) ?? code).tag(Optional(code))
                        }
                        Text("Another language").tag(String?.none)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.loeBackground)
            .loeNavigationTitle(heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(book)
                        dismiss()
                    }
                    .disabled(!book.canSave)
                }
            }
            .onAppear { titleFocused = book.title.isEmpty }
        }
    }

    private func number(_ label: LocalizedStringKey, _ value: Binding<Int?>, format: IntegerFormatStyle<Int>) -> some View {
        LabeledContent {
            TextField(label, value: value, format: format, prompt: Text(verbatim: "–"))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .accessibilityLabel(Text(label))
        } label: {
            Text(label)
        }
    }
}

#Preview {
    EnteredBookSheet("Add a book", book: EnteredBook(searchedFor: "Halo: The Fall of Reach")) { _ in }
}
