import SwiftUI

/// A shelved book's cover: the reader's photo, else Open Library's, found by the
/// cover id a book from Open Library keeps or by a catalogue book's print ISBN.
/// A book entered by hand has only its card.
struct ShelvedBookCover: View {
    let book: ShelvedBook
    let width: CGFloat
    var onCover: ((Covers.Loaded?) -> Void)?

    @Environment(CatalogueStore.self) private var catalogue
    @State private var art: CoverArt?

    var body: some View {
        BookCover(title: book.title, photo: book.coverPhoto, art: art, width: width, onCover: onCover)
            .task(id: book.workKey) {
                switch book.source {
                case .openLibrary:
                    art = book.openLibraryRecord.flatMap(CoverArt.init)
                case .catalogue:
                    // The same cover the book's page shows.
                    guard case .ready(let catalogue) = catalogue.state else { return }
                    art = await BookView.coverArt(for: book.work, shelved: book.erbID, in: catalogue)
                case .hand:
                    art = nil
                }
            }
    }
}
