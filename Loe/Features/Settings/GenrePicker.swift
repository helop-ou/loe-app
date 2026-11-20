import SwiftUI

/// The genres as chips to tap on and off.
struct GenrePicker: View {
    @Binding var selection: Set<Genre>

    /// Room for „Psühholoogiline“, the longest single word, with the icon and padding.
    @ScaledMetric(relativeTo: .callout) private var chipWidth = 170.0

    var body: some View {
        ChipGrid(minimumColumnWidth: chipWidth) {
            ForEach(Genre.allCases, id: \.self) { genre in
                chip(genre)
            }
        }
    }

    private func chip(_ genre: Genre) -> some View {
        let chosen = selection.contains(genre)
        return ChoiceChip(chosen: chosen) {
            if chosen { selection.remove(genre) } else { selection.insert(genre) }
        } label: {
            Text(genre.name)
        }
    }
}

#Preview {
    @Previewable @State var selection: Set<Genre> = [.crime, .psychological]
    GenrePicker(selection: $selection)
        .padding(20)
        .background(.loeBackground)
}
