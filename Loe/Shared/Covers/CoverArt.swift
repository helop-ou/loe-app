import Foundation

/// A cover to ask for. On Open Library by its id, which every search answer
/// carries and which is not rate limited, or by ISBN, which is. On ESTER by the
/// records of a catalogue book's editions, the one to prefer first. See
/// docs/library.md, "Covers".
nonisolated enum CoverArt: Hashable, Sendable {
    case id(Int)
    case isbn(String)
    case ester([String])

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

    /// A catalogue book's cover, from the ESTER records of these editions. Nil when
    /// none of them has a record, as for a book entered by hand.
    init?(erbIDs: [String]) {
        var seen: Set<String> = []
        let codes = erbIDs.compactMap(EPIK.code(erbID:)).filter { seen.insert($0).inserted }
        guard !codes.isEmpty else { return nil }
        self = .ester(Array(codes.prefix(EPIK.most)))
    }

    /// Open Library's large size, which a book's page needs. `default=false` answers
    /// 404 for a book with no cover instead of a blank image. Nil for ESTER, which
    /// is asked in two steps. See `EPIK`.
    var url: URL? {
        switch self {
        case .id(let id): URL(string: "https://covers.openlibrary.org/b/id/\(id)-L.jpg?default=false")
        case .isbn(let isbn): URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false")
        case .ester: nil
        }
    }

    /// Whose cover it is, to credit it.
    var isESTERs: Bool {
        if case .ester = self { true } else { false }
    }

    var isRateLimited: Bool {
        if case .isbn = self { true } else { false }
    }

    var fileName: String {
        switch self {
        case .id(let id): "id-\(id)"
        case .isbn(let isbn): "isbn-\(isbn)"
        // Every record, so a book's page and a shelf holding one edition differ.
        case .ester(let codes): "ester-\(codes.joined(separator: "-"))"
        }
    }
}

/// What a book's cover shows: the reader's own photo always, else the cover found
/// for it on Open Library or ESTER, else the card with the title.
nonisolated enum CoverChoice: Equatable, Sendable {
    case photo
    case found
    case card

    static func of(hasPhoto: Bool, hasFound: Bool) -> CoverChoice {
        if hasPhoto { return .photo }
        if hasFound { return .found }
        return .card
    }
}
