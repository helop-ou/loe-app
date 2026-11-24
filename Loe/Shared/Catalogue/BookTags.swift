import Foundation

/// What kind of book a work is, in a few of the bibliography's headings: the genres
/// most of its editions carry and, when it is not fiction, what it is about. See
/// docs/catalogue.md, "Tags".
nonisolated enum BookTags {
    /// A heading on a work's editions.
    struct Heading: Sendable, Equatable {
        let name: String
        /// A genre (655) and not a subject (650).
        let isGenre: Bool
        /// How many of the work's editions carry it.
        let editions: Int
        /// How many editions in the catalogue carry it. A rarer heading says more.
        let uses: Int
    }

    static let limit = 6

    /// Headings about an edition's format and not the book, and the one all fiction shares.
    static let leftOut: Set<String> = [
        "ilukirjandus", "e-raamatud", "audioraamatud", "kogutud teosed", "suurtähtraamatud",
        "võrguväljaanded", "separaadid", "CD-ROMid", "laserplaadid", "juubeliväljaanded",
    ]

    /// The headings to show, genres first, each kind with the rarest first.
    static func chosen(from headings: [Heading], editions: Int, fiction: Bool) -> [String] {
        // More than half the editions, so one oddly catalogued edition adds nothing.
        // Fiction's subjects are mostly the literature's nationality.
        let kept = headings.filter {
            $0.editions * 2 > editions && !leftOut.contains($0.name) && ($0.isGenre || !fiction)
        }
        let genres = kept.filter(\.isGenre)
        // A broader genre gives way to a narrower one that ends with it.
        let narrowest = genres.filter { genre in
            !genres.contains { $0.name != genre.name && $0.name.hasSuffix(genre.name) }
        }
        let ordered = narrowest.sorted(by: rarerFirst) + kept.filter { !$0.isGenre }.sorted(by: rarerFirst)
        return ordered.prefix(limit).map(\.name)
    }

    private static func rarerFirst(_ a: Heading, _ b: Heading) -> Bool {
        (a.uses, a.name) < (b.uses, b.name)
    }
}
