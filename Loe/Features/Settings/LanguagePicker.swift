import SwiftUI

/// The languages as chips, one of them chosen, for the first launch.
struct LanguagePicker: View {
    @Binding var selection: LoeLanguage

    var body: some View {
        // One to a row: the grid gives a chip the height its label needs at any text size.
        ChipGrid(minimumColumnWidth: 170, maximumColumns: 1) {
            ForEach(LoeLanguage.allCases, id: \.self) { language in
                ChoiceChip(chosen: selection == language, unchosenSymbol: nil) {
                    selection = language
                } label: {
                    LanguageLabel(language: language)
                }
            }
        }
    }
}

/// A language by its own name. The phone's own says which language that is.
struct LanguageLabel: View {
    let language: LoeLanguage

    var body: some View {
        if language == .system {
            Text("The phone's language: \(language.ownName())")
        } else {
            Text(verbatim: language.ownName())
        }
    }
}

#Preview {
    @Previewable @State var selection = LoeLanguage.system
    LanguagePicker(selection: $selection)
        .padding(20)
        .background(.loeBackground)
}
