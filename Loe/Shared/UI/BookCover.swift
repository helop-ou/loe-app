import SwiftUI

/// A book's cover at a given width and the 2:3 shape of a book. Shows the
/// reader's photo when there is one, otherwise the plain card with the title.
/// A cover keeps its own colours by night, with a hairline edge instead of a shadow.
struct BookCover: View {
    let title: String
    var photo: Data?
    let width: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let photo, let image = UIImage(data: photo) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: width * 1.5)
                .clipShape(.rect(cornerRadius: width * 0.04))
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: width * 0.04).strokeBorder(.loeHairline, lineWidth: 1)
                    }
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.14), radius: 3, y: 1)
                .accessibilityHidden(true)
        } else {
            BlankCover(title: title, width: width)
        }
    }
}
