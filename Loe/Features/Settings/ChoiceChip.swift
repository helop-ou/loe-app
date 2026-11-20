import SwiftUI

/// A choice as a chip to tap: filled, with a tick, once chosen.
struct ChoiceChip<Label: View>: View {
    let chosen: Bool
    /// What stands in the tick's place until the chip is chosen. A plus says there
    /// is more to add. With none the place stays empty, for one choice among a few.
    var unchosenSymbol: String? = "plus"
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: chosen ? "checkmark" : unchosenSymbol ?? "checkmark")
                    .font(.footnote.weight(.bold))
                    .opacity(chosen || unchosenSymbol != nil ? 1 : 0)
                    .accessibilityHidden(true)
                label
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(chosen ? Color.loeOnAccent : Color.loeInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: .infinity)
            .background(chosen ? Color.loeAccent : Color.loeCard, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(chosen ? Color.clear : Color.loeHairline))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// Two columns when both fit at their minimum width, otherwise one. The views in a
/// row share its height, so a label on two lines keeps the row even.
struct ChipGrid: Layout {
    let minimumColumnWidth: CGFloat
    var maximumColumns = 2
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
        min(maximumColumns, width >= 2 * minimumColumnWidth + spacing ? 2 : 1)
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
