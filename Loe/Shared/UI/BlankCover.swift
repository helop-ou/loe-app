import SwiftUI

/// The card for a book with no cover: paper with the title in Newsreader. Like a real
/// cover it keeps its colours at night, with a hairline edge instead of a shadow.
struct BlankCover: View {
    let title: String
    let width: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.04)
            .fill(.loeCoverBlank)
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(LoeFont.newsreader(size: max(width * 0.15, 8)))
                    .foregroundStyle(.loeInk)
                    .environment(\.colorScheme, .light)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .padding(width * 0.1)
            }
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: width * 0.04).strokeBorder(.loeHairline, lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.12), radius: 2, y: 1)
            .frame(width: width, height: width * 1.5)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        BlankCover(title: "Tõde ja õigus", width: 56)
        BlankCover(title: "Mees, kes teadis ussisõnu", width: 120)
    }
    .padding()
    .background(.loeBackground)
}
