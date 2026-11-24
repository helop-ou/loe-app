import Foundation

/// A cover on Open Library: by its id, which every search answer carries and which
/// is not rate limited, or by ISBN, which is. See docs/library.md, "Covers".
nonisolated enum CoverArt: Hashable, Sendable {
    case id(Int)
    case isbn(String)

    /// A book from Open Library's cover: its own id, else its ISBN.
    init?(_ record: OpenLibraryRecord) {
        if let id = record.coverID {
            self = .id(id)
        } else if let isbn = record.isbn {
            self = .isbn(isbn)
        } else {
            return nil
        }
    }

    /// The large size, which a book's page needs. `default=false` answers 404 for a
    /// book with no cover instead of a blank image.
    var url: URL {
        switch self {
        case .id(let id): URL(string: "https://covers.openlibrary.org/b/id/\(id)-L.jpg?default=false")!
        case .isbn(let isbn): URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false")!
        }
    }

    var isRateLimited: Bool {
        if case .isbn = self { true } else { false }
    }

    var fileName: String {
        switch self {
        case .id(let id): "id-\(id)"
        case .isbn(let isbn): "isbn-\(isbn)"
        }
    }
}

/// What a book's cover shows: the reader's own photo always, else Open Library's
/// cover, else the card with the title.
nonisolated enum CoverChoice: Equatable, Sendable {
    case photo
    case openLibrary
    case card

    static func of(hasPhoto: Bool, hasOpenLibrary: Bool) -> CoverChoice {
        if hasPhoto { return .photo }
        if hasOpenLibrary { return .openLibrary }
        return .card
    }
}
