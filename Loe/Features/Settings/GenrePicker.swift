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

/// Two columns when both fit at their minimum width, otherwise one. The views in a
/// row share its height, so a label on two lines keeps the row even.
private struct ChipGrid: Layout {
    let minimumColumnWidth: CGFloat
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 2 * minimumColumnWidth + spacing
        let heights = rowHeights(width: width, subviews: subviews)
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(heights.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columns(for: bounds.width)
        let columnWidth = self.columnWidth(bounds.width, columns)
        var y = bounds.minY
        for (row, height) in rowHeights(width: bounds.width, subviews: subviews).enumerated() {
            for column in 0..<columns where row * columns + column < subviews.count {
                subviews[row * columns + column].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (columnWidth + spacing), y: y),
                    proposal: ProposedViewSize(width: columnWidth, height: height)
                )
            }
            y += height + spacing
        }
    }

    private func columns(for width: CGFloat) -> Int {
        width >= 2 * minimumColumnWidth + spacing ? 2 : 1
    }

    private func columnWidth(_ width: CGFloat, _ columns: Int) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func rowHeights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        let columns = columns(for: width)
        let proposal = ProposedViewSize(width: columnWidth(width, columns), height: nil)
        return stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)].map { $0.sizeThatFits(proposal).height }.max() ?? 0
        }
    }
}

#Preview {
    @Previewable @State var selection: Set<Genre> = [.crime, .psychological]
    GenrePicker(selection: $selection)
        .padding(20)
        .background(.loeBackground)
}
