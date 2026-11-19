import SwiftUI

/// A book's cover at a given width and the 2:3 shape of a book. Shows the
/// reader's photo when there is one, otherwise Open Library's cover when it has
/// one, otherwise the plain card with the title. A cover keeps its own colours by
/// night, with a hairline edge instead of a shadow.
struct BookCover: View {
    let title: String
    var photo: Data?
    /// Open Library's cover, asked for only when there is no photo.
    var art: CoverArt?
    let width: CGFloat
    var covers: Covers = .live
    /// Told when Open Library's cover arrives, or nil when there is none.
    var onCover: ((Covers.Loaded?) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    /// Open Library's cover, decoded once when it arrives.
    @State private var loaded: UIImage?

    private struct Request: Equatable {
        let art: CoverArt?
        let hasPhoto: Bool
    }

    var body: some View {
        Group {
            switch CoverChoice.of(hasPhoto: photo != nil, hasOpenLibrary: loaded != nil) {
            case .photo: picture(photo.flatMap(UIImage.init(data:)))
            case .openLibrary: picture(loaded)
            case .card: BlankCover(title: title, width: width)
            }
        }
        .task(id: Request(art: art, hasPhoto: photo != nil)) {
            // A photo hides the cover, so it is not asked for until the photo goes.
            guard let art, photo == nil else { return }
            let cover = await covers.cover(art)
            guard !Task.isCancelled else { return }
            loaded = cover.flatMap { UIImage(data: $0.data) }
            onCover?(cover)
        }
    }

    @ViewBuilder
    private func picture(_ image: UIImage?) -> some View {
        if let image {
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
