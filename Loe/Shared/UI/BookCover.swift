import SwiftUI

/// A book's cover at a given width and the 2:3 shape of a book. Shows the
/// reader's photo when there is one, otherwise the cover Open Library or ESTER
/// has for it, otherwise the plain card with the title. A cover keeps its own
/// colours by night, with a hairline edge instead of a shadow.
struct BookCover: View {
    let title: String
    var photo: Data?
    /// The cover to look for, asked for only when there is no photo.
    var art: CoverArt?
    let width: CGFloat
    var covers: Covers = .live
    var pictures: CoverPictures = .shared
    /// Told when the cover that was looked for arrives, or nil when there is none.
    var onCover: ((Covers.Loaded?) -> Void)?

    /// How a cover that arrives takes its card's place, and how what it colours
    /// follows. One that is ready shows with the first frame, with nothing to fade from.
    static let arrival = Animation.easeOut(duration: 0.25)

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var found: Found?

    /// The cover that was found, with the cover it was found for: a view can be
    /// given another book before that book's own cover arrives.
    private struct Found {
        let art: CoverArt
        let picture: UIImage
    }

    private struct Request: Equatable {
        let art: CoverArt?
        let hasPhoto: Bool
    }

    private var foundPicture: UIImage? {
        guard let art, photo == nil else { return nil }
        if let found, found.art == art { return found.picture }
        return pictures.ready(art, width: width)
    }

    var body: some View {
        let foundPicture = foundPicture
        // One on top of the other, so a cover fades in over its card.
        ZStack {
            switch CoverChoice.of(hasPhoto: photo != nil, hasFound: foundPicture != nil) {
            case .photo:
                picture(photo.flatMap(UIImage.init(data:)))
            case .found:
                picture(foundPicture)
                    .transition(.opacity)
            case .card:
                BlankCover(title: title, width: width)
                    .transition(.opacity)
            }
        }
        .task(id: Request(art: art, hasPhoto: photo != nil)) {
            // A photo hides the cover, so it is not asked for until the photo goes.
            guard let art, photo == nil else { return }
            let cover = await covers.cover(art)
            guard !Task.isCancelled else { return }
            var picture: UIImage?
            if let cover {
                picture = await pictures.picture(of: cover.data, for: art, width: width, scale: displayScale)
                guard !Task.isCancelled else { return }
            }
            withAnimation(Self.arrival) {
                found = picture.map { Found(art: art, picture: $0) }
                onCover?(cover)
            }
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
