import SwiftUI

/// A shelved book's cover: the reader's photo, else the one Open Library or ESTER
/// has for it. A book with neither shows its card.
struct ShelvedBookCover: View {
    let book: ShelvedBook
    let width: CGFloat
    var onCover: ((Covers.Loaded?) -> Void)?

    var body: some View {
        BookCover(title: book.title, photo: book.coverPhoto, art: book.coverArt, width: width, onCover: onCover)
    }
}
