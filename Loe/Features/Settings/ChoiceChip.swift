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
