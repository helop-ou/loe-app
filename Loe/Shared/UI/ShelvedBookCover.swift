import SwiftUI

/// A shelved book's cover: the reader's photo, else Open Library's for a book
/// found there. Any other book shows its card.
struct ShelvedBookCover: View {
    let book: ShelvedBook
    let width: CGFloat
    var onCover: ((Covers.Loaded?) -> Void)?

    var body: some View {
        BookCover(title: book.title, photo: book.coverPhoto, art: book.coverArt, width: width, onCover: onCover)
    }
}
