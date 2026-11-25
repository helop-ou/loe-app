import SwiftUI

/// A book's cover where books are listed: search results, the rows of covers on a
/// book's page and Read next. A list shows what the phone already has, which is
/// the reader's own photo of a book on a shelf, or the cover the book's page or a
/// shelf found for it. It asks only by Open Library's cover id.
/// See docs/library.md, "Covers".
struct ListedCover: View {
    let work: CatalogueWork
    /// The reader's own photo, for a book that is on a shelf.
    var photo: Data?
    let width: CGFloat

    var body: some View {
        let art = Self.art(for: work)
        BookCover(title: work.title, photo: photo, art: art, asks: art?.isAskedForInLists ?? false, width: width)
    }

    /// Every edition's record and not only the newest, which are all a page asks
    /// about: a shelf keeps a cover under the edition it holds, which may be old.
    static func art(for work: CatalogueWork) -> CoverArt? {
        if let abroad = work.editions[0].openLibrary { return CoverArt(abroad) }
        return CoverArt(erbIDs: work.editions.map(\.erbID), title: work.title, most: .max)
    }
}
